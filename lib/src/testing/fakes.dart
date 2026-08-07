import 'dart:async';
import 'dart:typed_data';

import '../auth/auth.dart';
import '../backup/backup.dart';
import '../network/network.dart';
import '../sync/sync.dart';

final class RecordingDelay implements Delay {
  final List<Duration> waits = <Duration>[];
  @override
  Future<void> wait(Duration duration) async => waits.add(duration);
}

final class ScriptedNetworkTransport implements NetworkTransport {
  ScriptedNetworkTransport(Iterable<Object> script)
      : _script = List<Object>.from(script);

  final List<Object> _script;
  final List<NetworkRequest> requests = <NetworkRequest>[];

  @override
  Future<NetworkResponse> send(NetworkRequest request) async {
    requests.add(request);
    if (_script.isEmpty) throw StateError('No scripted response.');
    final next = _script.removeAt(0);
    if (next is NetworkResponse) return next;
    throw next;
  }
}

final class FakeOidcClient implements OidcClient {
  FakeOidcClient({required this.authorized, required this.refreshed});
  AuthTokens authorized;
  AuthTokens refreshed;
  int authorizationCalls = 0;
  int refreshCalls = 0;
  int revokeCalls = 0;

  @override
  Future<AuthTokens> authorize(OidcAuthorizationRequest request) async {
    authorizationCalls++;
    return authorized;
  }

  @override
  Future<AuthTokens> refresh(String refreshToken) async {
    refreshCalls++;
    return refreshed;
  }

  @override
  Future<void> revoke(String refreshToken) async {
    revokeCalls++;
  }
}

final class FakeRemoteSyncPort implements RemoteSyncPort {
  final List<List<SyncMutation>> pushedBatches = <List<SyncMutation>>[];
  final List<ChangePage> pullPages = <ChangePage>[];
  PushResult Function(List<SyncMutation> mutations)? onPush;

  @override
  Future<PushResult> push(
    String workspaceId,
    List<SyncMutation> mutations,
  ) async {
    pushedBatches.add(List<SyncMutation>.unmodifiable(mutations));
    return onPush?.call(mutations) ??
        PushResult(
          acknowledgements: mutations
              .map((mutation) => MutationAcknowledgement(
                    mutationId: mutation.mutationId,
                    disposition: PushDisposition.applied,
                    authoritativeVersion: (mutation.baseVersion ?? 0) + 1,
                  ))
              .toList(growable: false),
        );
  }

  @override
  Future<ChangePage> pull(String workspaceId, String? cursor) async =>
      pullPages.isEmpty
          ? const ChangePage(
              changes: <PulledChange>[],
              nextCursor: null,
              hasMore: false,
            )
          : pullPages.removeAt(0);
}

/// Non-cryptographic checksum for deterministic tests only. Production code
/// must inject a reviewed SHA-256 implementation from a maintained package.
final class TestChecksum implements BackupChecksum {
  const TestChecksum();
  @override
  String get algorithm => 'test-sum-v1';
  @override
  Future<String> calculate(Uint8List bytes) async =>
      bytes.fold<int>(0, (sum, byte) => (sum + byte) % 65536).toRadixString(16);
}

final class InMemoryBackupSource implements BackupSource {
  InMemoryBackupSource(this.bytes, {this.schemaVersion = 1});

  Uint8List bytes;
  @override
  final int schemaVersion;
  bool committed = false;
  bool discarded = false;

  @override
  Future<Uint8List> exportDatabase() async => Uint8List.fromList(bytes);

  @override
  Future<StagedRestore> stageRestore(
    Uint8List bytes,
    int sourceSchemaVersion,
  ) async =>
      _MemoryStagedRestore(
        bytes: bytes,
        onCommit: (restored) {
          this.bytes = Uint8List.fromList(restored);
          committed = true;
        },
        onDiscard: () => discarded = true,
      );
}

final class _MemoryStagedRestore implements StagedRestore {
  _MemoryStagedRestore({
    required this.bytes,
    required this.onCommit,
    required this.onDiscard,
  });

  final Uint8List bytes;
  final void Function(Uint8List bytes) onCommit;
  final void Function() onDiscard;

  @override
  Future<void> verify() async {
    if (bytes.isEmpty) throw StateError('Staged database is empty.');
  }

  @override
  Future<void> migrate() async {}

  @override
  Future<void> commit() async => onCommit(bytes);

  @override
  Future<void> discard() async => onDiscard();
}
