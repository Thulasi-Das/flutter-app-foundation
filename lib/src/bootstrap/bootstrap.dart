import 'dart:async';

enum BootstrapPhase { idle, running, ready, failed }

final class StartupStep {
  const StartupStep({
    required this.id,
    required this.run,
    this.required = true,
  });

  final String id;
  final Future<void> Function() run;
  final bool required;
}

final class BootstrapFailure {
  const BootstrapFailure({required this.stepId, required this.error});

  final String stepId;
  final Object error;
}

final class BootstrapSnapshot {
  const BootstrapSnapshot({
    required this.phase,
    this.activeStepId,
    this.failure,
    this.elapsed = Duration.zero,
  });

  final BootstrapPhase phase;
  final String? activeStepId;
  final BootstrapFailure? failure;
  final Duration elapsed;
}

abstract interface class MonotonicClock {
  Duration now();
}

final class StopwatchClock implements MonotonicClock {
  StopwatchClock() : _stopwatch = Stopwatch()..start();

  final Stopwatch _stopwatch;

  @override
  Duration now() => _stopwatch.elapsed;
}

final class BootstrapCoordinator {
  BootstrapCoordinator(
    List<StartupStep> steps, {
    MonotonicClock? clock,
  })  : _steps = List<StartupStep>.unmodifiable(steps),
        _clock = clock ?? StopwatchClock();

  final List<StartupStep> _steps;
  final MonotonicClock _clock;
  final StreamController<BootstrapSnapshot> _snapshots =
      StreamController<BootstrapSnapshot>.broadcast(sync: true);
  BootstrapSnapshot _snapshot = const BootstrapSnapshot(
    phase: BootstrapPhase.idle,
  );
  Future<BootstrapSnapshot>? _activeStart;

  BootstrapSnapshot get snapshot => _snapshot;
  Stream<BootstrapSnapshot> get snapshots => _snapshots.stream;

  Future<BootstrapSnapshot> start() =>
      _activeStart ??= _run().whenComplete(() => _activeStart = null);

  Future<BootstrapSnapshot> retry() => start();

  Future<BootstrapSnapshot> _run() async {
    final start = _clock.now();
    for (final step in _steps) {
      _emit(BootstrapSnapshot(
        phase: BootstrapPhase.running,
        activeStepId: step.id,
        elapsed: _clock.now() - start,
      ));
      try {
        await step.run();
      } on Object catch (error) {
        if (step.required) {
          _emit(BootstrapSnapshot(
            phase: BootstrapPhase.failed,
            activeStepId: step.id,
            failure: BootstrapFailure(stepId: step.id, error: error),
            elapsed: _clock.now() - start,
          ));
          return _snapshot;
        }
      }
    }
    _emit(BootstrapSnapshot(
      phase: BootstrapPhase.ready,
      elapsed: _clock.now() - start,
    ));
    return _snapshot;
  }

  void _emit(BootstrapSnapshot value) {
    _snapshot = value;
    _snapshots.add(value);
  }

  Future<void> dispose() => _snapshots.close();
}
