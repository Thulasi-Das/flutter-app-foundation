import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'key_value_store.dart';

/// A [KeyValueStore] persisted as one JSON file.
///
/// Writes are serialized and atomic (write to a temporary file, then rename),
/// so a crash mid-write never leaves a truncated file. A corrupt file is
/// treated as empty rather than crashing startup. Suitable for small
/// preference sets on mobile and desktop; obtain the directory from
/// `path_provider` in the app.
final class FileKeyValueStore implements KeyValueStore {
  FileKeyValueStore(this.file);

  final File file;
  Map<String, String>? _cache;
  Future<void> _tail = Future<void>.value();

  Future<Map<String, String>> _load() async {
    final cached = _cache;
    if (cached != null) return cached;
    var loaded = <String, String>{};
    if (await file.exists()) {
      try {
        final decoded = jsonDecode(await file.readAsString());
        if (decoded is Map<String, Object?>) {
          loaded = <String, String>{
            for (final entry in decoded.entries)
              if (entry.value is String) entry.key: entry.value! as String,
          };
        }
      } on FormatException {
        loaded = <String, String>{};
      }
    }
    return _cache = loaded;
  }

  Future<T> _serialized<T>(Future<T> Function() action) {
    final result = _tail.then((_) => action());
    _tail = result.then<void>((_) {}, onError: (Object _) {});
    return result;
  }

  Future<void> _persist(Map<String, String> values) async {
    await file.parent.create(recursive: true);
    final temp = File('${file.path}.tmp');
    await temp.writeAsString(jsonEncode(values), flush: true);
    await temp.rename(file.path);
  }

  @override
  Future<String?> read(String key) =>
      _serialized(() async => (await _load())[key]);

  @override
  Future<Map<String, String>> readAll() =>
      _serialized(() async => Map<String, String>.unmodifiable(await _load()));

  @override
  Future<void> write(String key, String value) => _serialized(() async {
    final values = Map<String, String>.of(await _load())..[key] = value;
    await _persist(values);
    _cache = values;
  });

  @override
  Future<void> delete(String key) => _serialized(() async {
    final current = await _load();
    if (!current.containsKey(key)) return;
    final values = Map<String, String>.of(current)..remove(key);
    await _persist(values);
    _cache = values;
  });
}
