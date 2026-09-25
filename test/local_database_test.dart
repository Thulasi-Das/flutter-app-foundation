import 'package:flutter_app_foundation/flutter_app_foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('transaction rolls back changes when action fails', () async {
    final database = InMemoryLocalDatabase();

    await expectLater(
      database.transaction<void>((tx) {
        tx.put(
          const StoredRecord(
            table: 'items',
            id: 'one',
            values: <String, Object?>{'safe': true},
            version: 1,
          ),
        );
        throw StateError('rollback');
      }),
      throwsStateError,
    );

    final rows = await database.transaction((tx) => tx.readAll('items'));
    expect(rows, isEmpty);
    await database.close();
  });

  test('migration plan rejects gaps', () {
    expect(
      () => MigrationPlan(<DatabaseMigration>[
        const _Migration(0, 1),
        const _Migration(2, 3),
      ]),
      throwsArgumentError,
    );
  });

  test('database migrates along continuous path', () async {
    final database = InMemoryLocalDatabase();
    final plan = MigrationPlan(<DatabaseMigration>[
      const _Migration(0, 1),
      const _Migration(1, 2),
    ]);
    await database.migrate(plan, 2);
    expect(database.schemaVersion, 2);
    final version = await database.transaction((tx) => tx.metadata('version'));
    expect(version, '2');
    await database.close();
  });
}

final class _Migration implements DatabaseMigration {
  const _Migration(this.fromVersion, this.toVersion);
  @override
  final int fromVersion;
  @override
  final int toVersion;
  @override
  Future<void> migrate(DatabaseTransaction transaction) async =>
      transaction.setMetadata('version', '$toVersion');
}
