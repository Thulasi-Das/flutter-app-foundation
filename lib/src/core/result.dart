/// A value that is either a success ([Ok]) or a typed failure ([Err]).
///
/// Use it at repository and view-model boundaries where a failure is an
/// expected outcome that callers must handle, rather than an exception.
sealed class Result<T, E extends Object> {
  const Result();

  /// Runs [action] and captures any thrown [E] as an [Err].
  ///
  /// Errors that are not an [E] are rethrown so programming errors are never
  /// silently converted into domain failures.
  static Future<Result<T, E>> guard<T, E extends Object>(
    Future<T> Function() action,
  ) async {
    try {
      return Ok<T, E>(await action());
    } on E catch (error) {
      return Err<T, E>(error);
    }
  }

  bool get isOk => this is Ok<T, E>;
  bool get isErr => this is Err<T, E>;

  T? get valueOrNull => switch (this) {
    Ok<T, E>(:final value) => value,
    Err<T, E>() => null,
  };

  E? get errorOrNull => switch (this) {
    Ok<T, E>() => null,
    Err<T, E>(:final error) => error,
  };

  /// Returns the value or throws the captured error.
  T get valueOrThrow => switch (this) {
    Ok<T, E>(:final value) => value,
    Err<T, E>(:final error) => throw error,
  };

  R fold<R>(R Function(T value) onOk, R Function(E error) onErr) =>
      switch (this) {
        Ok<T, E>(:final value) => onOk(value),
        Err<T, E>(:final error) => onErr(error),
      };

  Result<R, E> map<R>(R Function(T value) transform) => switch (this) {
    Ok<T, E>(:final value) => Ok<R, E>(transform(value)),
    Err<T, E>(:final error) => Err<R, E>(error),
  };

  Result<T, F> mapError<F extends Object>(F Function(E error) transform) =>
      switch (this) {
        Ok<T, E>(:final value) => Ok<T, F>(value),
        Err<T, E>(:final error) => Err<T, F>(transform(error)),
      };
}

final class Ok<T, E extends Object> extends Result<T, E> {
  const Ok(this.value);
  final T value;

  @override
  bool operator ==(Object other) => other is Ok<T, E> && other.value == value;

  @override
  int get hashCode => Object.hash(Ok, value);

  @override
  String toString() => 'Ok($value)';
}

final class Err<T, E extends Object> extends Result<T, E> {
  const Err(this.error);
  final E error;

  @override
  bool operator ==(Object other) => other is Err<T, E> && other.error == error;

  @override
  int get hashCode => Object.hash(Err, error);

  @override
  String toString() => 'Err($error)';
}
