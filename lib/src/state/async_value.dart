/// The state of an asynchronous read: loading, data, or error.
///
/// Loading and error states keep the last successful value (if any) so
/// screens can keep showing stale content while refreshing or after a failed
/// refresh.
sealed class AsyncValue<T> {
  const AsyncValue();

  const factory AsyncValue.loading({AsyncData<T>? previous}) = AsyncLoading<T>;
  const factory AsyncValue.data(T value) = AsyncData<T>;
  const factory AsyncValue.error(
    Object error, {
    StackTrace? stackTrace,
    AsyncData<T>? previous,
  }) = AsyncError<T>;

  bool get isLoading => this is AsyncLoading<T>;
  bool get hasError => this is AsyncError<T>;

  /// True when a value is available, including a stale one.
  bool get hasValue => _data != null;

  T? get valueOrNull => _data?.value;
  Object? get errorOrNull => switch (this) {
    AsyncError<T>(:final error) => error,
    _ => null,
  };

  AsyncData<T>? get _data => switch (this) {
    final AsyncData<T> data => data,
    AsyncLoading<T>(:final previous) => previous,
    AsyncError<T>(:final previous) => previous,
  };

  /// Returns a loading state that keeps this state's value.
  AsyncLoading<T> toLoading() => AsyncLoading<T>(previous: _data);

  R when<R>({
    required R Function(T value) data,
    required R Function(Object error, StackTrace? stackTrace) error,
    required R Function() loading,
  }) => switch (this) {
    AsyncData<T>(:final value) => data(value),
    AsyncError<T>(error: final e, :final stackTrace) => error(e, stackTrace),
    AsyncLoading<T>() => loading(),
  };
}

final class AsyncLoading<T> extends AsyncValue<T> {
  const AsyncLoading({this.previous});
  final AsyncData<T>? previous;

  @override
  String toString() => 'AsyncLoading<$T>(previous: $previous)';
}

final class AsyncData<T> extends AsyncValue<T> {
  const AsyncData(this.value);
  final T value;

  @override
  bool operator ==(Object other) =>
      other is AsyncData<T> && other.value == value;

  @override
  int get hashCode => Object.hash(AsyncData, value);

  @override
  String toString() => 'AsyncData<$T>($value)';
}

final class AsyncError<T> extends AsyncValue<T> {
  const AsyncError(this.error, {this.stackTrace, this.previous});
  final Object error;
  final StackTrace? stackTrace;
  final AsyncData<T>? previous;

  @override
  String toString() => 'AsyncError<$T>($error)';
}
