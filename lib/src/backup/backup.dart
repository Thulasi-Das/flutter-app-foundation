import 'dart:convert';
import 'dart:typed_data';

import '../testing/primitives.dart';

final class BackupManifest {
  const BackupManifest({
    required this.formatVersion,
    required this.schemaVersion,
    required this.appVersion,
    required this.createdAt,
    required this.sizeBytes,
    required this.checksumAlgorithm,
    required this.checksum,
    required this.encrypted,
  });

  final int formatVersion;
  final int schemaVersion;
  final String appVersion;
  final DateTime createdAt;
  final int sizeBytes;
  final String checksumAlgorithm;
  final String checksum;
  final bool encrypted;

  Map<String, Object?> toJson() => <String, Object?>{
    'formatVersion': formatVersion,
    'schemaVersion': schemaVersion,
    'appVersion': appVersion,
    'createdAt': createdAt.toUtc().toIso8601String(),
    'sizeBytes': sizeBytes,
    'checksumAlgorithm': checksumAlgorithm,
    'checksum': checksum,
    'encrypted': encrypted,
  };

  static BackupManifest fromJson(Map<String, Object?> json) {
    return BackupManifest(
      formatVersion: json['formatVersion']! as int,
      schemaVersion: json['schemaVersion']! as int,
      appVersion: json['appVersion']! as String,
      createdAt: DateTime.parse(json['createdAt']! as String).toUtc(),
      sizeBytes: json['sizeBytes']! as int,
      checksumAlgorithm: json['checksumAlgorithm']! as String,
      checksum: json['checksum']! as String,
      encrypted: json['encrypted']! as bool,
    );
  }
}

final class BackupArchive {
  const BackupArchive({required this.manifest, required this.payload});
  final BackupManifest manifest;
  final Uint8List payload;
}

abstract interface class BackupChecksum {
  String get algorithm;
  Future<String> calculate(Uint8List bytes);
}

abstract interface class BackupEncryption {
  Future<Uint8List> encrypt(Uint8List bytes);
  Future<Uint8List> decrypt(Uint8List bytes);
}

abstract interface class BackupSource {
  int get schemaVersion;
  Future<Uint8List> exportDatabase();
  Future<StagedRestore> stageRestore(Uint8List bytes, int sourceSchemaVersion);
}

abstract interface class StagedRestore {
  Future<void> verify();
  Future<void> migrate();
  Future<void> commit();
  Future<void> discard();
}

abstract interface class BackupDestination {
  Future<String> save(BackupArchive archive);
  Future<List<BackupDescriptor>> list();
  Future<BackupArchive> load(String id);
  Future<void> delete(String id);
}

final class BackupDescriptor {
  const BackupDescriptor({required this.id, required this.manifest});
  final String id;
  final BackupManifest manifest;
}

final class BackupCoordinator {
  const BackupCoordinator({
    required BackupSource source,
    required BackupChecksum checksum,
    required Clock clock,
    required String appVersion,
  }) : _source = source,
       _checksum = checksum,
       _clock = clock,
       _appVersion = appVersion;

  final BackupSource _source;
  final BackupChecksum _checksum;
  final Clock _clock;
  final String _appVersion;

  Future<BackupArchive> create({BackupEncryption? encryption}) async {
    final raw = await _source.exportDatabase();
    final payload = encryption == null ? raw : await encryption.encrypt(raw);
    return BackupArchive(
      manifest: BackupManifest(
        formatVersion: 1,
        schemaVersion: _source.schemaVersion,
        appVersion: _appVersion,
        createdAt: _clock.nowUtc(),
        sizeBytes: payload.length,
        checksumAlgorithm: _checksum.algorithm,
        checksum: await _checksum.calculate(payload),
        encrypted: encryption != null,
      ),
      payload: payload,
    );
  }

  Future<void> restore(
    BackupArchive archive, {
    BackupEncryption? encryption,
  }) async {
    if (archive.manifest.formatVersion != 1) {
      throw StateError('Unsupported backup format.');
    }
    if (archive.payload.length != archive.manifest.sizeBytes) {
      throw StateError('Backup size does not match its manifest.');
    }
    if (_checksum.algorithm != archive.manifest.checksumAlgorithm ||
        await _checksum.calculate(archive.payload) !=
            archive.manifest.checksum) {
      throw StateError('Backup checksum verification failed.');
    }
    if (archive.manifest.encrypted && encryption == null) {
      throw StateError('This backup requires a decryption adapter.');
    }
    final bytes = archive.manifest.encrypted
        ? await encryption!.decrypt(archive.payload)
        : archive.payload;
    final staging = await _source.stageRestore(
      bytes,
      archive.manifest.schemaVersion,
    );
    try {
      await staging.verify();
      await staging.migrate();
      await staging.verify();
      await staging.commit();
    } on Object {
      await staging.discard();
      rethrow;
    }
  }
}

final class BackupArchiveCodec {
  const BackupArchiveCodec();

  Uint8List encode(BackupArchive archive) {
    final envelope = <String, Object?>{
      'manifest': archive.manifest.toJson(),
      'payloadBase64': base64Encode(archive.payload),
    };
    return Uint8List.fromList(utf8.encode(jsonEncode(envelope)));
  }

  BackupArchive decode(Uint8List bytes) {
    final envelope = jsonDecode(utf8.decode(bytes)) as Map<String, Object?>;
    return BackupArchive(
      manifest: BackupManifest.fromJson(
        envelope['manifest']! as Map<String, Object?>,
      ),
      payload: base64Decode(envelope['payloadBase64']! as String),
    );
  }
}

final class InMemoryBackupDestination implements BackupDestination {
  final Map<String, BackupArchive> _archives = <String, BackupArchive>{};
  int _sequence = 0;

  @override
  Future<String> save(BackupArchive archive) async {
    final id = 'backup-${++_sequence}';
    _archives[id] = archive;
    return id;
  }

  @override
  Future<List<BackupDescriptor>> list() async => _archives.entries
      .map(
        (entry) =>
            BackupDescriptor(id: entry.key, manifest: entry.value.manifest),
      )
      .toList(growable: false);

  @override
  Future<BackupArchive> load(String id) async =>
      _archives[id] ?? (throw StateError('Backup not found.'));

  @override
  Future<void> delete(String id) async {
    _archives.remove(id);
  }
}
