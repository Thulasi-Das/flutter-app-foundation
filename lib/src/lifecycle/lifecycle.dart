import 'dart:async';

enum ApplicationLifecycle { detached, resumed, inactive, hidden, paused }

abstract interface class LifecycleMonitor {
  ApplicationLifecycle get current;
  Stream<ApplicationLifecycle> get changes;
}

abstract interface class BackgroundWorkScheduler {
  Future<void> requestOpportunisticSync(String workspaceId);
  Future<void> cancel(String workspaceId);
}

final class InMemoryLifecycleMonitor implements LifecycleMonitor {
  InMemoryLifecycleMonitor([
    ApplicationLifecycle initial = ApplicationLifecycle.resumed,
  ]) : _current = initial;

  ApplicationLifecycle _current;
  final StreamController<ApplicationLifecycle> _changes =
      StreamController<ApplicationLifecycle>.broadcast(sync: true);

  @override
  ApplicationLifecycle get current => _current;
  @override
  Stream<ApplicationLifecycle> get changes => _changes.stream;

  void update(ApplicationLifecycle value) {
    _current = value;
    _changes.add(value);
  }

  Future<void> dispose() => _changes.close();
}
