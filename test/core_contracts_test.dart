import 'dart:async';
import 'dart:math';
import 'dart:typed_data';

import 'package:flutter_app_foundation/flutter_app_foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Result', () {
    test('guard captures expected failures only', () async {
      final ok = await Result.guard<int, FormatException>(() async => 1);
      final err = await Result.guard<int, FormatException>(
        () async => throw const FormatException('bad'),
      );
      expect(ok, const Ok<int, FormatException>(1));
      expect(err.isErr, isTrue);
      expect(err.errorOrNull?.message, 'bad');
      await expectLater(
        Result.guard<int, FormatException>(() async => throw StateError('x')),
        throwsStateError,
      );
    });

    test('map, fold and valueOrThrow', () {
      const Result<int, String> ok = Ok(2);
      const Result<int, String> err = Err('nope');
      expect(ok.map((v) => v * 2).valueOrNull, 4);
      expect(err.map((v) => v * 2).errorOrNull, 'nope');
      expect(ok.fold((v) => 'v$v', (e) => e), 'v2');
      expect(err.mapError((e) => e.length).errorOrNull, 4);
      expect(() => err.valueOrThrow, throwsA('nope'));
    });
  });

  test('UUID v4 generator produces unique RFC 4122 identifiers', () {
    final ids = UuidV4Generator();
    final values = List<String>.generate(500, (_) => ids.next());
    expect(values.toSet(), hasLength(500));
    expect(values.every(UuidV4Generator.pattern.hasMatch), isTrue);
  });

  test('secure random strings use the URL-safe alphabet', () {
    final value = secureRandomString(length: 64, random: Random(1));
    expect(value, hasLength(64));
    expect(RegExp(r'^[A-Za-z0-9\-._~]+$').hasMatch(value), isTrue);
  });

  group('AppVersion', () {
    test('orders releases and pre-releases', () {
      expect(AppVersion.parse('1.2.3') < AppVersion.parse('1.10.0'), isTrue);
      expect(
        AppVersion.parse('2.0.0-beta') < AppVersion.parse('2.0.0'),
        isTrue,
      );
      expect(AppVersion.parse('v1.2'), AppVersion.parse('1.2.0+77'));
      expect(AppVersion.tryParse('dev'), isNull);
    });

    test('configuration requires update only for parseable old releases', () {
      AppConfiguration config(String release, String? minimum) =>
          AppConfiguration(
            environment: AppEnvironment.production,
            apiBaseUri: Uri.parse('https://api.example.test'),
            release: release,
            buildNumber: '1',
            appId: 'app',
            minimumSupportedVersion: minimum,
          );
      expect(config('1.0.0', '1.1.0').requiresUpdate, isTrue);
      expect(config('1.1.0', '1.1.0').requiresUpdate, isFalse);
      expect(config('dev', '9.0.0').requiresUpdate, isFalse);
      expect(config('1.0.0', null).requiresUpdate, isFalse);
    });
  });

  test('SHA-256 backup checksum matches a known vector', () async {
    const checksum = Sha256BackupChecksum();
    expect(
      await checksum.calculate(Uint8List.fromList('abc'.codeUnits)),
      'ba7816bf8f01cfea414140de5dae2223b00361a396177a9cb410ff61f20015ad',
    );
  });

  group('Bootstrap', () {
    test('reports optional failures and honours step timeouts', () async {
      final failures = <(String, bool)>[];
      final coordinator = BootstrapCoordinator(
        <StartupStep>[
          StartupStep(
            id: 'optional',
            required: false,
            run: () async => throw StateError('x'),
          ),
          StartupStep(
            id: 'slow',
            timeout: const Duration(milliseconds: 10),
            run: () => Future<void>.delayed(const Duration(seconds: 5)),
          ),
        ],
        onStepFailed: (failure, {required fatal}) =>
            failures.add((failure.stepId, fatal)),
      );
      final snapshot = await coordinator.start();
      expect(snapshot.phase, BootstrapPhase.failed);
      expect(snapshot.failure?.error, isA<TimeoutException>());
      expect(snapshot.failure?.stackTrace, isNotNull);
      expect(failures, <(String, bool)>[('optional', false), ('slow', true)]);
      await coordinator.dispose();
    });

    test('rejects duplicate step ids', () {
      Future<void> noop() async {}
      expect(
        () => BootstrapCoordinator(<StartupStep>[
          StartupStep(id: 'a', run: noop),
          StartupStep(id: 'a', run: noop),
        ]),
        throwsArgumentError,
      );
    });
  });

  group('Crash reporting', () {
    test('logging reporter records type but never the message', () async {
      final sink = InMemoryLogSink();
      final reporter = LoggingCrashReporter(
        StructuredLogger(sink: sink, clock: FakeClock(DateTime.utc(2026))),
      );
      await reporter.recordError(
        StateError('user@example.com'),
        StackTrace.current,
        fatal: true,
        source: 'zone',
      );
      final event = sink.events.single;
      expect(event.level, LogLevel.critical);
      expect(event.attributes, <String, Object?>{
        'errorType': 'StateError',
        'fatal': true,
        'source': 'zone',
      });
      expect(sink.diagnosticExport(), isNot(contains('user@example.com')));
    });

    test('fan-out reporter isolates failing reporters', () async {
      final sink = InMemoryLogSink();
      final reporter = FanOutCrashReporter(<CrashReporter>[
        _ThrowingReporter(),
        LoggingCrashReporter(
          StructuredLogger(sink: sink, clock: FakeClock(DateTime.utc(2026))),
        ),
      ]);
      await reporter.recordError(StateError('x'), null, fatal: false);
      expect(sink.events, hasLength(1));
    });

    test('fan-out log sink isolates failing sinks', () async {
      final memory = InMemoryLogSink();
      final logger = StructuredLogger(
        sink: FanOutLogSink(<LogSink>[_ThrowingSink(), memory]),
        clock: FakeClock(DateTime.utc(2026)),
      );
      await logger.record(LogLevel.info, 'app.started');
      expect(memory.events.single.code, 'app.started');
    });
  });
}

final class _ThrowingReporter implements CrashReporter {
  @override
  Future<void> recordError(
    Object error,
    StackTrace? stackTrace, {
    required bool fatal,
    String? source,
  }) async => throw StateError('reporter down');
}

final class _ThrowingSink implements LogSink {
  @override
  void write(LogEvent event) => throw StateError('sink down');
}
