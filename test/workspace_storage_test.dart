import 'dart:io';

import 'package:flutter_app_foundation/foundation_local_file_storage.dart';
import 'package:flutter_app_foundation/foundation_storage.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  StoreDescriptor localDescriptor([String provider = 'local_sqlite']) =>
      StoreDescriptor(
        storeId: 'store-1',
        workspaceId: 'workspace-1',
        provider: provider,
        privacyMode: PrivacyMode.localOnly,
        dataLocation: DataLocation.device,
        configuration: const <String, Object?>{
          'databasePath': '/private/app/vault.sqlite3',
        },
      );

  WorkspaceRecord record(String id, [int version = 1]) => WorkspaceRecord(
        collection: 'notes',
        recordId: id,
        values: <String, Object?>{'title': id, 'private': true},
        version: version,
        updatedAt: DateTime.utc(2026, 8, 24),
      );

  test('Django-compatible wire fields are stable', () {
    expect(localDescriptor().toJson(), containsPair('contractVersion', '1.0'));
    expect(
      localDescriptor().toJson(),
      containsPair('privacyMode', 'local_only'),
    );
    expect(localDescriptor().toJson(), containsPair('dataLocation', 'device'));
    expect(record('one').toJson(), containsPair('recordId', 'one'));
    final decoded = StoreDescriptor.fromJson(localDescriptor().toJson());
    expect(decoded.provider, localDescriptor().provider);
    expect(
      StoreErrorCode.invalidConfiguration.wireName,
      'invalid_configuration',
    );
  });

  test('registry supports product-owned provider adapters', () async {
    final registry = StoreRegistry()
      ..register('google_sheets', _MemoryFactory());
    final descriptor = StoreDescriptor(
      storeId: 'sheets',
      workspaceId: 'workspace-1',
      provider: 'google_sheets',
      privacyMode: PrivacyMode.directUserProvider,
      dataLocation: DataLocation.userCloud,
      secretReference: 'oauth://user/google',
    );
    final store = await registry.create(
      descriptor,
      secretLookup: (_) => <String, String>{'accessToken': 'memory-only'},
    );
    expect(store.descriptor, same(descriptor));
  });

  test('in-memory adapter honors paging and optimistic concurrency', () async {
    final store = InMemoryWorkspaceStore(localDescriptor());
    await store.put(record('a'));
    await store.put(record('b'));
    final first = await store.list(StoreQuery(collection: 'notes', limit: 1));
    expect(first.records.single.recordId, 'a');
    expect(first.nextCursor, '1');
    final second = await store.list(
      StoreQuery(collection: 'notes', cursor: first.nextCursor),
    );
    expect(second.records.single.recordId, 'b');
    await expectLater(
      store.put(record('a', 2), expectedVersion: 0),
      throwsA(
        isA<StoreException>().having(
          (error) => error.code,
          'code',
          StoreErrorCode.conflict,
        ),
      ),
    );
    await expectLater(
      store.delete('notes', 'missing', expectedVersion: 1),
      throwsA(isA<StoreException>()),
    );
  });

  test('privacy policy rejects credentials and direct database access', () {
    final inlineSecret = StoreDescriptor(
      storeId: 'database',
      workspaceId: 'workspace-1',
      provider: 'database',
      privacyMode: PrivacyMode.directUserProvider,
      dataLocation: DataLocation.userInfrastructure,
      configuration: const <String, Object?>{
        'host': 'db.example',
        'password': 'unsafe',
      },
    );
    expect(() => validateStoreDescriptor(inlineSecret), throwsArgumentError);

    final directDatabase = StoreDescriptor(
      storeId: 'database',
      workspaceId: 'workspace-1',
      provider: 'database',
      privacyMode: PrivacyMode.directUserProvider,
      dataLocation: DataLocation.userInfrastructure,
      configuration: const <String, Object?>{'host': 'db.example'},
      secretReference: 'vault://customer/database',
    );
    expect(() => validateStoreDescriptor(directDatabase), throwsArgumentError);
  });

  test('owner controls visible and recommended providers', () {
    final options = visibleProviderOptions(const <ProviderOption>[
      ProviderOption('local_sqlite', recommended: true),
      ProviderOption('airtable', enabled: false),
    ]);
    expect(options.map((option) => option.provider), <String>['local_sqlite']);
  });

  test('local file adapter persists workspace records', () async {
    final root = await Directory.systemTemp.createTemp('foundation-store-');
    addTearDown(() => root.delete(recursive: true));
    final registry = StoreRegistry()
      ..register('local_file', const LocalFileStoreFactory());
    final store = await registry.create(
      StoreDescriptor(
        storeId: 'files',
        workspaceId: 'workspace-1',
        provider: 'local_file',
        privacyMode: PrivacyMode.localOnly,
        dataLocation: DataLocation.device,
        configuration: <String, Object?>{'rootPath': root.path},
      ),
    );
    await store.put(record('persisted'));
    expect((await store.get('notes', 'persisted'))?.values['private'], true);
    await store.close();
  });

  test(
    'SQLite adapter creates its portable schema through product driver',
    () async {
      final drivers = _RecordingDriverFactory();
      final registry = StoreRegistry()
        ..register('local_sqlite', SqliteStoreFactory(drivers));
      final store = await registry.create(localDescriptor());
      expect(drivers.driver.statements.single, contains('foundation_records'));
      await store.close();
      expect(drivers.driver.closed, true);
    },
  );
}

final class _MemoryFactory implements StoreFactory {
  @override
  WorkspaceStore create(
    StoreDescriptor descriptor,
    Map<String, String> secrets,
  ) =>
      InMemoryWorkspaceStore(descriptor);
}

final class _RecordingDriverFactory implements WorkspaceSqliteDriverFactory {
  final _RecordingDriver driver = _RecordingDriver();

  @override
  Future<WorkspaceSqliteDriver> open(String databasePath) async => driver;
}

final class _RecordingDriver implements WorkspaceSqliteDriver {
  final List<String> statements = <String>[];
  bool closed = false;

  @override
  Future<int> execute(
    String sql, [
    List<Object?> parameters = const <Object?>[],
  ]) async {
    statements.add(sql);
    return 0;
  }

  @override
  Future<List<Map<String, Object?>>> query(
    String sql, [
    List<Object?> parameters = const <Object?>[],
  ]) async =>
      <Map<String, Object?>>[];

  @override
  Future<void> close() async {
    closed = true;
  }
}
