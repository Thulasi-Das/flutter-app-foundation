import 'dart:typed_data';

import 'package:flutter_app_foundation/flutter_app_foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test(
    'sync pushes queued mutation and durably advances pull cursor',
    () async {
      final clock = FakeClock(DateTime.utc(2026));
      final store = InMemorySyncStore();
      final remote = FakeRemoteSyncPort()
        ..pullPages.add(
          const ChangePage(
            changes: <PulledChange>[
              PulledChange(
                changeId: 'change-1',
                workspaceId: 'workspace-1',
                entityType: 'example',
                entityId: 'entity-2',
                version: 1,
                values: <String, Object?>{'status': 'ready'},
              ),
            ],
            nextCursor: 'cursor-1',
            hasMore: false,
          ),
        );
      await store.enqueue(
        SyncMutation(
          mutationId: 'mutation-1',
          workspaceId: 'workspace-1',
          entityType: 'example',
          entityId: 'entity-1',
          operation: MutationOperation.create,
          baseVersion: 0,
          payload: const <String, Object?>{'status': 'new'},
          occurredAt: clock.nowUtc(),
        ),
      );
      final coordinator = SyncCoordinator(
        remote: remote,
        store: store,
        clock: clock,
      );

      final result = await coordinator.synchronize('workspace-1');

      expect(result.phase, SyncPhase.idle);
      expect(store.mutations['mutation-1']?.status, MutationStatus.applied);
      expect(await store.cursor('workspace-1'), 'cursor-1');
      expect(store.records, hasLength(1));
      await coordinator.dispose();
    },
  );

  test('pull rejects cross-workspace data without advancing cursor', () async {
    final store = InMemorySyncStore();
    await expectLater(
      store.applyPageAtomically('workspace-1', const <PulledChange>[
        PulledChange(
          changeId: 'bad',
          workspaceId: 'workspace-2',
          entityType: 'example',
          entityId: 'entity',
          version: 1,
          values: <String, Object?>{},
        ),
      ], 'unsafe-cursor'),
      throwsStateError,
    );
    expect(await store.cursor('workspace-1'), isNull);
    expect(store.records, isEmpty);
  });

  test('backup round-trip verifies before staged commit', () async {
    final clock = FakeClock(DateTime.utc(2026));
    final source = InMemoryBackupSource(Uint8List.fromList(<int>[1, 2, 3]));
    final coordinator = BackupCoordinator(
      source: source,
      checksum: const TestChecksum(),
      clock: clock,
      appVersion: '0.1.0',
    );
    final archive = await coordinator.create();
    source.bytes = Uint8List.fromList(<int>[9]);

    await coordinator.restore(archive);

    expect(source.bytes, <int>[1, 2, 3]);
    expect(source.committed, isTrue);
  });

  test('structured logger drops personal and secret attributes', () {
    final sink = InMemoryLogSink();
    final logger = StructuredLogger(
      sink: sink,
      clock: FakeClock(DateTime.utc(2026)),
    );
    logger.record(
      LogLevel.info,
      'sync.completed',
      attributes: const {
        'syncPhase': 'idle',
        'queuedCount': 0,
        'token': 'secret',
        'taskTitle': 'private content',
      },
    );

    expect(sink.events.single.attributes, <String, Object?>{
      'syncPhase': 'idle',
      'queuedCount': 0,
    });
  });
}
