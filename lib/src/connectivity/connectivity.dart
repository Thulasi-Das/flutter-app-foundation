import 'dart:async';

enum ConnectivityHint { unknown, offline, constrained, online }

abstract interface class ConnectivityMonitor {
  ConnectivityHint get current;
  Stream<ConnectivityHint> get changes;
}

final class InMemoryConnectivityMonitor implements ConnectivityMonitor {
  InMemoryConnectivityMonitor([
    ConnectivityHint initial = ConnectivityHint.unknown,
  ]) : _current = initial;

  ConnectivityHint _current;
  final StreamController<ConnectivityHint> _changes =
      StreamController<ConnectivityHint>.broadcast(sync: true);

  @override
  ConnectivityHint get current => _current;
  @override
  Stream<ConnectivityHint> get changes => _changes.stream;

  void update(ConnectivityHint hint) {
    if (hint == _current) return;
    _current = hint;
    _changes.add(hint);
  }

  Future<void> dispose() => _changes.close();
}
