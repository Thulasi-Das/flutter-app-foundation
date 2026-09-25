import 'dart:typed_data';

import 'package:flutter_app_foundation/flutter_app_foundation.dart';

Future<void> main() async {
  final database = InMemoryLocalDatabase();
  await database.transaction<void>(
    (tx) => tx.put(
      const StoredRecord(
        table: 'health',
        id: 'one',
        values: <String, Object?>{'ok': true},
        version: 1,
      ),
    ),
  );
  assert(
    (await database.transaction((tx) => tx.readAll('health'))).length == 1,
  );

  final clock = FakeClock(DateTime.utc(2026));
  final store = InMemorySyncStore();
  await store.enqueue(
    SyncMutation(
      mutationId: 'm-1',
      workspaceId: 'w-1',
      entityType: 'example',
      entityId: 'e-1',
      operation: MutationOperation.create,
      baseVersion: 0,
      payload: const <String, Object?>{'value': 1},
      occurredAt: clock.nowUtc(),
    ),
  );
  final sync = SyncCoordinator(
    remote: FakeRemoteSyncPort(),
    store: store,
    clock: clock,
  );
  assert((await sync.synchronize('w-1')).phase == SyncPhase.idle);

  final source = InMemoryBackupSource(Uint8List.fromList(<int>[1, 2, 3]));
  final backup = BackupCoordinator(
    source: source,
    checksum: const TestChecksum(),
    clock: clock,
    appVersion: 'self-check',
  );
  await backup.restore(await backup.create());
  assert(source.committed);

  final logs = InMemoryLogSink();
  StructuredLogger(sink: logs, clock: clock).record(
    LogLevel.info,
    'self_check.complete',
    attributes: const <String, Object?>{'status': 'ok', 'token': 'removed'},
  );
  assert(logs.events.single.attributes.length == 1);

  await sync.dispose();
  await database.close();
}
