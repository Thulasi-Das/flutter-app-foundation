import 'dart:async';
import 'dart:convert';

import '../testing/primitives.dart';

enum MutationOperation { create, update, delete }

enum MutationStatus { pending, sending, applied, conflicted, permanentlyFailed }

enum SyncPhase { idle, syncing, offline, actionRequired, failed }

enum PushDisposition { applied, conflict, rejected }

final class SyncMutation {
  const SyncMutation({
    required this.mutationId,
    required this.workspaceId,
    required this.entityType,
    required this.entityId,
    required this.operation,
    required this.baseVersion,
    required this.payload,
    required this.occurredAt,
    this.actorId,
    this.deviceId,
    this.attemptCount = 0,
    this.nextAttemptAt,
    this.status = MutationStatus.pending,
  });

  final String mutationId;
  final String workspaceId;
  final String entityType;
  final String entityId;
  final MutationOperation operation;

  /// Null when creating an entity that has no authoritative remote version.
  final int? baseVersion;
  final Map<String, Object?> payload;
  final DateTime occurredAt;
  final String? actorId;
  final String? deviceId;
  final int attemptCount;
  final DateTime? nextAttemptAt;
  final MutationStatus status;

  int get payloadBytes => utf8.encode(jsonEncode(payload)).length;

  SyncMutation copyWith({
    int? attemptCount,
    DateTime? nextAttemptAt,
    MutationStatus? status,
  }) => SyncMutation(
    mutationId: mutationId,
    workspaceId: workspaceId,
    entityType: entityType,
    entityId: entityId,
    operation: operation,
    baseVersion: baseVersion,
    payload: payload,
    occurredAt: occurredAt,
    actorId: actorId,
    deviceId: deviceId,
    attemptCount: attemptCount ?? this.attemptCount,
    nextAttemptAt: nextAttemptAt ?? this.nextAttemptAt,
    status: status ?? this.status,
  );
}

final class PulledChange {
  const PulledChange({
    required this.changeId,
    required this.workspaceId,
    required this.entityType,
    required this.entityId,
    required this.version,
    required this.values,
    this.deleted = false,
  });

  final String changeId;
  final String workspaceId;
  final String entityType;
  final String entityId;
  final int version;
  final Map<String, Object?> values;
  final bool deleted;
}

final class MutationAcknowledgement {
  const MutationAcknowledgement({
    required this.mutationId,
    required this.disposition,
    this.authoritativeVersion,
    this.code,
    this.remoteValues,
  });

  final String mutationId;
  final PushDisposition disposition;
  final int? authoritativeVersion;
  final String? code;
  final Map<String, Object?>? remoteValues;
}

final class PushResult {
  const PushResult({required this.acknowledgements});
  final List<MutationAcknowledgement> acknowledgements;
}

final class ChangePage {
  const ChangePage({
    required this.changes,
    required this.nextCursor,
    required this.hasMore,
  });

  final List<PulledChange> changes;
  final String? nextCursor;
  final bool hasMore;
}

final class SyncConflict {
  const SyncConflict({
    required this.mutation,
    required this.code,
    this.remoteValues,
  });

  final SyncMutation mutation;
  final String code;
  final Map<String, Object?>? remoteValues;
}

abstract interface class RemoteSyncPort {
  Future<PushResult> push(String workspaceId, List<SyncMutation> mutations);
  Future<ChangePage> pull(String workspaceId, String? cursor);
}

abstract interface class SyncStore {
  Future<void> enqueue(SyncMutation mutation);
  Future<List<SyncMutation>> pending(
    String workspaceId, {
    required DateTime now,
    required int maxCount,
    required int maxPayloadBytes,
  });
  Future<void> markSending(List<String> mutationIds);
  Future<void> markRetryableFailure(
    List<String> mutationIds,
    DateTime nextAttemptAt,
  );
  Future<void> markApplied(String mutationId, int? authoritativeVersion);
  Future<void> recordConflict(SyncConflict conflict);
  Future<void> markPermanentFailure(String mutationId, String code);
  Future<String?> cursor(String workspaceId);
  Future<void> applyPageAtomically(
    String workspaceId,
    List<PulledChange> changes,
    String? nextCursor,
  );
  Future<int> pendingCount(String workspaceId);
}

final class SyncSnapshot {
  const SyncSnapshot({
    required this.workspaceId,
    required this.phase,
    this.queuedCount = 0,
    this.lastSyncedAt,
    this.errorCode,
  });

  final String workspaceId;
  final SyncPhase phase;
  final int queuedCount;
  final DateTime? lastSyncedAt;
  final String? errorCode;
}

final class SyncCoordinator {
  SyncCoordinator({
    required RemoteSyncPort remote,
    required SyncStore store,
    required Clock clock,
    this.maxBatchCount = 100,
    this.maxBatchBytes = 512 * 1024,
    this.maximumPullPages = 100,
  }) : _remote = remote,
       _store = store,
       _clock = clock;

  final RemoteSyncPort _remote;
  final SyncStore _store;
  final Clock _clock;
  final int maxBatchCount;
  final int maxBatchBytes;
  final int maximumPullPages;
  final Map<String, Future<SyncSnapshot>> _active =
      <String, Future<SyncSnapshot>>{};
  final StreamController<SyncSnapshot> _snapshots =
      StreamController<SyncSnapshot>.broadcast(sync: true);

  Stream<SyncSnapshot> get snapshots => _snapshots.stream;

  Future<SyncSnapshot> synchronize(String workspaceId) {
    final existing = _active[workspaceId];
    if (existing != null) return existing;
    final run = _run(workspaceId);
    _active[workspaceId] = run;
    return run.whenComplete(() => _active.remove(workspaceId));
  }

  Future<SyncSnapshot> _run(String workspaceId) async {
    _emit(SyncSnapshot(workspaceId: workspaceId, phase: SyncPhase.syncing));
    var sendingIds = const <String>[];
    try {
      final pending = await _store.pending(
        workspaceId,
        now: _clock.nowUtc(),
        maxCount: maxBatchCount,
        maxPayloadBytes: maxBatchBytes,
      );
      if (pending.isNotEmpty) {
        sendingIds = pending.map((mutation) => mutation.mutationId).toList();
        await _store.markSending(sendingIds);
        final pushed = await _remote.push(workspaceId, pending);
        final byId = <String, SyncMutation>{
          for (final mutation in pending) mutation.mutationId: mutation,
        };
        final acknowledgedIds = <String>{};
        for (final acknowledgement in pushed.acknowledgements) {
          final mutation = byId[acknowledgement.mutationId];
          if (mutation == null) continue;
          acknowledgedIds.add(acknowledgement.mutationId);
          switch (acknowledgement.disposition) {
            case PushDisposition.applied:
              await _store.markApplied(
                mutation.mutationId,
                acknowledgement.authoritativeVersion,
              );
              break;
            case PushDisposition.conflict:
              await _store.recordConflict(
                SyncConflict(
                  mutation: mutation,
                  code: acknowledgement.code ?? 'version_conflict',
                  remoteValues: acknowledgement.remoteValues,
                ),
              );
              break;
            case PushDisposition.rejected:
              await _store.markPermanentFailure(
                mutation.mutationId,
                acknowledgement.code ?? 'mutation_rejected',
              );
              break;
          }
        }
        final missingIds = sendingIds
            .where((mutationId) => !acknowledgedIds.contains(mutationId))
            .toList(growable: false);
        if (missingIds.isNotEmpty) {
          await _store.markRetryableFailure(
            missingIds,
            _clock.nowUtc().add(const Duration(seconds: 5)),
          );
        }
      }

      var cursor = await _store.cursor(workspaceId);
      for (var pageIndex = 0; pageIndex < maximumPullPages; pageIndex++) {
        final page = await _remote.pull(workspaceId, cursor);
        await _store.applyPageAtomically(
          workspaceId,
          page.changes,
          page.nextCursor,
        );
        cursor = page.nextCursor;
        if (!page.hasMore) break;
        if (pageIndex == maximumPullPages - 1) {
          throw StateError('Pull page limit exceeded.');
        }
      }

      final snapshot = SyncSnapshot(
        workspaceId: workspaceId,
        phase: SyncPhase.idle,
        queuedCount: await _store.pendingCount(workspaceId),
        lastSyncedAt: _clock.nowUtc(),
      );
      _emit(snapshot);
      return snapshot;
    } on Object {
      if (sendingIds.isNotEmpty) {
        await _store.markRetryableFailure(
          sendingIds,
          _clock.nowUtc().add(const Duration(seconds: 5)),
        );
      }
      final snapshot = SyncSnapshot(
        workspaceId: workspaceId,
        phase: SyncPhase.failed,
        queuedCount: await _store.pendingCount(workspaceId),
        errorCode: 'sync_failed',
      );
      _emit(snapshot);
      return snapshot;
    }
  }

  void _emit(SyncSnapshot snapshot) => _snapshots.add(snapshot);
  Future<void> dispose() => _snapshots.close();
}

/// Deterministic reference store. SQLite adapters must preserve the same
/// transaction boundaries and durable statuses.
final class InMemorySyncStore implements SyncStore {
  final Map<String, SyncMutation> mutations = <String, SyncMutation>{};
  final Map<String, String?> cursors = <String, String?>{};
  final Map<String, PulledChange> records = <String, PulledChange>{};
  final Map<String, SyncConflict> conflicts = <String, SyncConflict>{};
  final Map<String, String> permanentFailures = <String, String>{};

  @override
  Future<void> enqueue(SyncMutation mutation) async {
    mutations.putIfAbsent(mutation.mutationId, () => mutation);
  }

  @override
  Future<List<SyncMutation>> pending(
    String workspaceId, {
    required DateTime now,
    required int maxCount,
    required int maxPayloadBytes,
  }) async {
    final eligible =
        mutations.values
            .where(
              (mutation) =>
                  mutation.workspaceId == workspaceId &&
                  mutation.status == MutationStatus.pending &&
                  (mutation.nextAttemptAt == null ||
                      !mutation.nextAttemptAt!.isAfter(now)),
            )
            .toList()
          ..sort((left, right) {
            final order = left.occurredAt.compareTo(right.occurredAt);
            return order != 0
                ? order
                : left.mutationId.compareTo(right.mutationId);
          });
    final result = <SyncMutation>[];
    var bytes = 0;
    for (final mutation in eligible) {
      if (result.length >= maxCount) break;
      if (result.isNotEmpty &&
          bytes + mutation.payloadBytes > maxPayloadBytes) {
        break;
      }
      result.add(mutation);
      bytes += mutation.payloadBytes;
    }
    return result;
  }

  @override
  Future<void> markSending(List<String> mutationIds) async {
    for (final id in mutationIds) {
      final mutation = mutations[id];
      if (mutation != null) {
        mutations[id] = mutation.copyWith(status: MutationStatus.sending);
      }
    }
  }

  @override
  Future<void> markRetryableFailure(
    List<String> mutationIds,
    DateTime nextAttemptAt,
  ) async {
    for (final id in mutationIds) {
      final mutation = mutations[id];
      if (mutation != null && mutation.status == MutationStatus.sending) {
        mutations[id] = mutation.copyWith(
          status: MutationStatus.pending,
          attemptCount: mutation.attemptCount + 1,
          nextAttemptAt: nextAttemptAt,
        );
      }
    }
  }

  @override
  Future<void> markApplied(String mutationId, int? authoritativeVersion) async {
    final mutation = mutations[mutationId];
    if (mutation != null) {
      mutations[mutationId] = mutation.copyWith(status: MutationStatus.applied);
    }
  }

  @override
  Future<void> recordConflict(SyncConflict conflict) async {
    conflicts[conflict.mutation.mutationId] = conflict;
    mutations[conflict.mutation.mutationId] = conflict.mutation.copyWith(
      status: MutationStatus.conflicted,
    );
  }

  @override
  Future<void> markPermanentFailure(String mutationId, String code) async {
    final mutation = mutations[mutationId];
    if (mutation != null) {
      mutations[mutationId] = mutation.copyWith(
        status: MutationStatus.permanentlyFailed,
      );
      permanentFailures[mutationId] = code;
    }
  }

  @override
  Future<String?> cursor(String workspaceId) async => cursors[workspaceId];

  @override
  Future<void> applyPageAtomically(
    String workspaceId,
    List<PulledChange> changes,
    String? nextCursor,
  ) async {
    final staged = <String, PulledChange>{...records};
    for (final change in changes) {
      if (change.workspaceId != workspaceId) {
        throw StateError('Cross-workspace pull result rejected.');
      }
      final key =
          '${change.workspaceId}:${change.entityType}:${change.entityId}';
      final current = staged[key];
      if (current == null || change.version > current.version) {
        staged[key] = change;
      }
    }
    records
      ..clear()
      ..addAll(staged);
    cursors[workspaceId] = nextCursor;
  }

  @override
  Future<int> pendingCount(String workspaceId) async => mutations.values
      .where(
        (mutation) =>
            mutation.workspaceId == workspaceId &&
            (mutation.status == MutationStatus.pending ||
                mutation.status == MutationStatus.sending),
      )
      .length;
}
