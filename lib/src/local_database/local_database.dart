import 'dart:async';

final class StoredRecord {
  const StoredRecord({
    required this.table,
    required this.id,
    required this.values,
    required this.version,
    this.deleted = false,
  });

  final String table;
  final String id;
  final Map<String, Object?> values;
  final int version;
  final bool deleted;
}

abstract interface class DatabaseTransaction {
  StoredRecord? read(String table, String id);
  List<StoredRecord> readAll(String table);
  void put(StoredRecord record);
  void remove(String table, String id);
  String? metadata(String key);
  void setMetadata(String key, String value);
}

abstract interface class LocalDatabase {
  int get schemaVersion;
  Future<T> transaction<T>(FutureOr<T> Function(DatabaseTransaction tx) action);
  Stream<void> watch(String table);
  Future<void> close();
}

abstract interface class DatabaseMigration {
  int get fromVersion;
  int get toVersion;
  Future<void> migrate(DatabaseTransaction transaction);
}

final class MigrationPlan {
  factory MigrationPlan(List<DatabaseMigration> migrations) {
    final sorted = <DatabaseMigration>[...migrations]
      ..sort((left, right) => left.fromVersion.compareTo(right.fromVersion));
    for (var index = 0; index < sorted.length; index++) {
      final migration = sorted[index];
      if (migration.toVersion != migration.fromVersion + 1) {
        throw ArgumentError('Migrations must advance exactly one version.');
      }
      if (index > 0 && sorted[index - 1].toVersion != migration.fromVersion) {
        throw ArgumentError('Migrations must form a continuous chain.');
      }
    }
    return MigrationPlan._(List<DatabaseMigration>.unmodifiable(sorted));
  }

  const MigrationPlan._(this.migrations);

  final List<DatabaseMigration> migrations;

  List<DatabaseMigration> path(int from, int to) {
    if (to < from) throw ArgumentError('Downgrade migrations are unsupported.');
    if (to == from) return const <DatabaseMigration>[];
    final path = migrations
        .where((migration) =>
            migration.fromVersion >= from && migration.toVersion <= to)
        .toList(growable: false);
    if (path.isEmpty ||
        path.first.fromVersion != from ||
        path.last.toVersion != to ||
        path.length != to - from) {
      throw StateError('No complete migration path from $from to $to.');
    }
    return path;
  }
}

/// Deterministic reference adapter. Production apps provide a SQLite adapter.
final class InMemoryLocalDatabase implements LocalDatabase {
  InMemoryLocalDatabase({int schemaVersion = 0})
      : _schemaVersion = schemaVersion;

  int _schemaVersion;
  Map<String, Map<String, StoredRecord>> _tables =
      <String, Map<String, StoredRecord>>{};
  Map<String, String> _metadata = <String, String>{};
  final Map<String, StreamController<void>> _watchers =
      <String, StreamController<void>>{};
  Future<void> _transactionTail = Future<void>.value();
  bool _closed = false;

  @override
  int get schemaVersion => _schemaVersion;

  @override
  Future<T> transaction<T>(
    FutureOr<T> Function(DatabaseTransaction tx) action,
  ) {
    if (_closed) throw StateError('Database is closed.');
    final completer = Completer<T>();
    _transactionTail = _transactionTail.then<void>((_) async {
      try {
        completer.complete(await _performTransaction(action));
      } on Object catch (error, stackTrace) {
        completer.completeError(error, stackTrace);
      }
    });
    return completer.future;
  }

  Future<T> _performTransaction<T>(
    FutureOr<T> Function(DatabaseTransaction tx) action,
  ) async {
    final tables = _cloneTables(_tables);
    final metadata = <String, String>{..._metadata};
    final tx = _MemoryTransaction(tables, metadata);
    final result = await action(tx);
    _tables = tables;
    _metadata = metadata;
    for (final table in tx.changedTables) {
      _watchers[table]?.add(null);
    }
    return result;
  }

  Future<void> migrate(MigrationPlan plan, int targetVersion) async {
    for (final migration in plan.path(_schemaVersion, targetVersion)) {
      await transaction<void>((tx) => migration.migrate(tx));
      _schemaVersion = migration.toVersion;
    }
  }

  @override
  Stream<void> watch(String table) {
    if (_closed) return const Stream<void>.empty();
    return (_watchers[table] ??=
            StreamController<void>.broadcast(sync: true))
        .stream;
  }

  @override
  Future<void> close() async {
    _closed = true;
    for (final watcher in _watchers.values) {
      await watcher.close();
    }
    _watchers.clear();
  }

  static Map<String, Map<String, StoredRecord>> _cloneTables(
    Map<String, Map<String, StoredRecord>> source,
  ) =>
      source.map(
        (table, rows) => MapEntry(table, <String, StoredRecord>{...rows}),
      );
}

final class _MemoryTransaction implements DatabaseTransaction {
  _MemoryTransaction(this.tables, this.metadataValues);

  final Map<String, Map<String, StoredRecord>> tables;
  final Map<String, String> metadataValues;
  final Set<String> changedTables = <String>{};

  @override
  StoredRecord? read(String table, String id) => tables[table]?[id];

  @override
  List<StoredRecord> readAll(String table) =>
      List<StoredRecord>.unmodifiable(tables[table]?.values ?? const []);

  @override
  void put(StoredRecord record) {
    (tables[record.table] ??= <String, StoredRecord>{})[record.id] = record;
    changedTables.add(record.table);
  }

  @override
  void remove(String table, String id) {
    tables[table]?.remove(id);
    changedTables.add(table);
  }

  @override
  String? metadata(String key) => metadataValues[key];

  @override
  void setMetadata(String key, String value) {
    metadataValues[key] = value;
    changedTables.add('__metadata');
  }
}
