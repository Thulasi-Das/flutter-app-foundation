import 'dart:async';

import 'package:flutter/foundation.dart';

import 'async_value.dart';

/// A view-model primitive that loads a value and exposes it as [AsyncValue].
///
/// - Overlapping [run] calls are safe: only the latest call's result is kept.
/// - Results arriving after [dispose] are ignored instead of throwing.
/// - Loading and error states keep the previous value for stale-while-
///   revalidate screens.
///
/// ```dart
/// final todos = AsyncController<List<Todo>>(load: repository.fetchTodos)
///   ..refresh();
/// ```
class AsyncController<T> extends ChangeNotifier
    implements ValueListenable<AsyncValue<T>> {
  AsyncController({
    Future<T> Function()? load,
    AsyncValue<T> initial = const AsyncLoading(),
    this.onError,
  }) : _load = load,
       _value = initial;

  final Future<T> Function()? _load;

  /// Called for every failure, e.g. to forward to a `CrashReporter`.
  final void Function(Object error, StackTrace stackTrace)? onError;

  AsyncValue<T> _value;
  int _generation = 0;
  bool _disposed = false;

  @override
  AsyncValue<T> get value => _value;

  bool get isDisposed => _disposed;

  /// Re-runs the `load` function given to the constructor.
  Future<void> refresh() {
    final load = _load;
    if (load == null) {
      throw StateError('AsyncController was created without a load function.');
    }
    return run(load);
  }

  /// Runs [action], publishing loading and then data or error.
  Future<void> run(Future<T> Function() action) async {
    final generation = ++_generation;
    final loading = _value.toLoading();
    _set(loading);
    try {
      final result = await action();
      if (generation == _generation) _set(AsyncData<T>(result));
    } on Object catch (error, stackTrace) {
      onError?.call(error, stackTrace);
      if (generation == _generation) {
        _set(
          AsyncError<T>(
            error,
            stackTrace: stackTrace,
            previous: loading.previous,
          ),
        );
      }
    }
  }

  /// Replaces the value directly, e.g. after an optimistic local update.
  void set(T value) {
    _generation++;
    _set(AsyncData<T>(value));
  }

  void _set(AsyncValue<T> next) {
    if (_disposed) return;
    _value = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }
}
