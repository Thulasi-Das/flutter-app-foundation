import '../bootstrap/bootstrap.dart';

abstract interface class Clock {
  DateTime nowUtc();
}

final class SystemClock implements Clock {
  const SystemClock();

  @override
  DateTime nowUtc() => DateTime.now().toUtc();
}

final class FakeClock implements Clock, MonotonicClock {
  FakeClock(DateTime value) : _value = value.toUtc();

  DateTime _value;
  Duration _elapsed = Duration.zero;

  @override
  DateTime nowUtc() => _value;

  @override
  Duration now() => _elapsed;

  void advance(Duration duration) {
    _value = _value.add(duration);
    _elapsed += duration;
  }
}

abstract interface class IdGenerator {
  String next();
}

final class SequentialIdGenerator implements IdGenerator {
  SequentialIdGenerator({this.prefix = 'test'});

  final String prefix;
  int _value = 0;

  @override
  String next() => '$prefix-${++_value}';
}
