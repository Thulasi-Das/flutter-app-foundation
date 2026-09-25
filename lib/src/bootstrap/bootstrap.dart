import 'dart:async';

enum BootstrapPhase { idle, running, ready, failed }

final class StartupStep {
  const StartupStep({
    required this.id,
    required this.run,
    this.required = true,
    this.timeout,
  });

  final String id;
  final Future<void> Function() run;

  /// Optional steps may fail without blocking startup; failures are still
  /// reported through `BootstrapCoordinator.onStepFailed`.
  final bool required;

  /// Fails the step with a [TimeoutException] when exceeded.
  final Duration? timeout;
}

final class BootstrapFailure {
  const BootstrapFailure({
    required this.stepId,
    required this.error,
    this.stackTrace,
  });

  final String stepId;
  final Object error;
  final StackTrace? stackTrace;
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
    this.onStepFailed,
  }) : _steps = List<StartupStep>.unmodifiable(steps),
       _clock = clock ?? StopwatchClock() {
    final ids = <String>{};
    for (final step in _steps) {
      if (!ids.add(step.id)) {
        throw ArgumentError.value(step.id, 'steps', 'Duplicate step id.');
      }
    }
  }

  /// Called for every failed step, required or optional — typically wired to
  /// a `CrashReporter`.
  final void Function(BootstrapFailure failure, {required bool fatal})?
  onStepFailed;

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
      _emit(
        BootstrapSnapshot(
          phase: BootstrapPhase.running,
          activeStepId: step.id,
          elapsed: _clock.now() - start,
        ),
      );
      try {
        final timeout = step.timeout;
        await (timeout == null ? step.run() : step.run().timeout(timeout));
      } on Object catch (error, stackTrace) {
        final failure = BootstrapFailure(
          stepId: step.id,
          error: error,
          stackTrace: stackTrace,
        );
        onStepFailed?.call(failure, fatal: step.required);
        if (step.required) {
          _emit(
            BootstrapSnapshot(
              phase: BootstrapPhase.failed,
              activeStepId: step.id,
              failure: failure,
              elapsed: _clock.now() - start,
            ),
          );
          return _snapshot;
        }
      }
    }
    _emit(
      BootstrapSnapshot(
        phase: BootstrapPhase.ready,
        elapsed: _clock.now() - start,
      ),
    );
    return _snapshot;
  }

  void _emit(BootstrapSnapshot value) {
    _snapshot = value;
    _snapshots.add(value);
  }

  Future<void> dispose() => _snapshots.close();
}
