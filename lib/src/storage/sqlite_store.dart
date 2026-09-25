import 'dart:convert';

import 'workspace_storage.dart';

abstract interface class WorkspaceSqliteDriver {
  /// Returns the number of affected rows for data-changing statements.
  Future<int> execute(String sql, [List<Object?> parameters = const []]);
  Future<List<Map<String, Object?>>> query(
    String sql, [
    List<Object?> parameters = const [],
  ]);
  Future<void> close();
}

abstract interface class WorkspaceSqliteDriverFactory {
  Future<WorkspaceSqliteDriver> open(String databasePath);
}

final class SqliteWorkspaceStore implements WorkspaceStore {
  SqliteWorkspaceStore._(this.descriptor, this._driver);

  static Future<SqliteWorkspaceStore> open(
    StoreDescriptor descriptor,
    WorkspaceSqliteDriver driver,
  ) async {
    final store = SqliteWorkspaceStore._(descriptor, driver);
    await driver.execute('''
CREATE TABLE IF NOT EXISTS foundation_records (
 workspace_id TEXT NOT NULL, collection_name TEXT NOT NULL,
 record_id TEXT NOT NULL, values_json TEXT NOT NULL,
 version INTEGER NOT NULL, updated_at TEXT NOT NULL,
 deleted INTEGER NOT NULL DEFAULT 0,
 PRIMARY KEY (workspace_id, collection_name, record_id)
)''');
    return store;
  }

  @override
  final StoreDescriptor descriptor;
  final WorkspaceSqliteDriver _driver;

  @override
  final StoreCapabilities capabilities = const StoreCapabilities(
    transactions: true,
    offline: true,
  );

  @override
  Future<bool> health() async => (await _driver.query('SELECT 1')).isNotEmpty;

  @override
  Future<WorkspaceRecord?> get(String collection, String recordId) async {
    final rows = await _driver.query(
      'SELECT values_json, version, updated_at, deleted '
      'FROM foundation_records '
      'WHERE workspace_id = ? AND collection_name = ? AND record_id = ?',
      <Object?>[descriptor.workspaceId, collection, recordId],
    );
    if (rows.isEmpty) return null;
    final row = rows.single;
    return WorkspaceRecord(
      collection: collection,
      recordId: recordId,
      values: Map<String, Object?>.from(
        jsonDecode(row['values_json']! as String) as Map,
      ),
      version: row['version']! as int,
      updatedAt: DateTime.parse(row['updated_at']! as String),
      deleted: (row['deleted']! as int) != 0,
    );
  }

  @override
  Future<StorePage> list(StoreQuery query) async {
    final rows = await _driver.query(
      'SELECT record_id, values_json, version, updated_at, deleted '
      'FROM foundation_records WHERE workspace_id = ? AND collection_name = ? '
      'ORDER BY record_id',
      <Object?>[descriptor.workspaceId, query.collection],
    );
    final records = rows
        .map(
          (row) => WorkspaceRecord(
            collection: query.collection,
            recordId: row['record_id']! as String,
            values: Map<String, Object?>.from(
              jsonDecode(row['values_json']! as String) as Map,
            ),
            version: row['version']! as int,
            updatedAt: DateTime.parse(row['updated_at']! as String),
            deleted: (row['deleted']! as int) != 0,
          ),
        )
        .where(
          (record) =>
              (query.includeDeleted || !record.deleted) &&
              query.filters.entries.every(
                (filter) => record.values[filter.key] == filter.value,
              ),
        )
        .toList();
    final offset = int.tryParse(query.cursor ?? '0');
    if (offset == null || offset < 0) {
      throw const StoreException(StoreErrorCode.invalidConfiguration);
    }
    final start = offset > records.length ? records.length : offset;
    final requestedEnd = start + query.limit;
    final end = requestedEnd > records.length ? records.length : requestedEnd;
    return StorePage(
      records.sublist(start, end),
      nextCursor: end < records.length ? '$end' : null,
    );
  }

  @override
  Future<void> put(WorkspaceRecord record, {int? expectedVersion}) async {
    final commonValues = <Object?>[
      jsonEncode(record.values),
      record.version,
      record.updatedAt.toUtc().toIso8601String(),
      record.deleted ? 1 : 0,
    ];
    if (expectedVersion == null) {
      await _driver.execute(
        'INSERT INTO foundation_records VALUES (?, ?, ?, ?, ?, ?, ?) '
        'ON CONFLICT(workspace_id, collection_name, record_id) DO UPDATE SET '
        'values_json=excluded.values_json, version=excluded.version, '
        'updated_at=excluded.updated_at, deleted=excluded.deleted',
        <Object?>[
          descriptor.workspaceId,
          record.collection,
          record.recordId,
          ...commonValues,
        ],
      );
      return;
    }
    final changed = await _driver.execute(
      'UPDATE foundation_records SET values_json = ?, version = ?, '
      'updated_at = ?, deleted = ? WHERE workspace_id = ? '
      'AND collection_name = ? AND record_id = ? AND version = ?',
      <Object?>[
        ...commonValues,
        descriptor.workspaceId,
        record.collection,
        record.recordId,
        expectedVersion,
      ],
    );
    if (changed != 1) throw const StoreException(StoreErrorCode.conflict);
  }

  @override
  Future<void> delete(
    String collection,
    String recordId, {
    int? expectedVersion,
  }) async {
    final versionClause = expectedVersion == null ? '' : ' AND version = ?';
    final changed = await _driver.execute(
      'DELETE FROM foundation_records WHERE workspace_id = ? '
      'AND collection_name = ? AND record_id = ?$versionClause',
      <Object?>[
        descriptor.workspaceId,
        collection,
        recordId,
        if (expectedVersion != null) expectedVersion,
      ],
    );
    if (expectedVersion != null && changed == 0) {
      throw const StoreException(StoreErrorCode.conflict);
    }
  }

  @override
  Future<void> close() => _driver.close();
}

final class SqliteStoreFactory implements StoreFactory {
  const SqliteStoreFactory(this.drivers);

  final WorkspaceSqliteDriverFactory drivers;

  @override
  Future<WorkspaceStore> create(
    StoreDescriptor descriptor,
    Map<String, String> secrets,
  ) async {
    final path = descriptor.configuration['databasePath'];
    if (path is! String || path.isEmpty) {
      throw const StoreException(StoreErrorCode.invalidConfiguration);
    }
    return SqliteWorkspaceStore.open(descriptor, await drivers.open(path));
  }
}
