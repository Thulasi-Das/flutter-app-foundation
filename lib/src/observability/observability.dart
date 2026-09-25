import 'dart:async';
import 'dart:convert';
import 'dart:developer' as developer;

import '../testing/primitives.dart';

enum LogLevel { debug, info, warning, error, critical }

final class LogEvent {
  const LogEvent({
    required this.timestamp,
    required this.level,
    required this.code,
    required this.attributes,
    this.correlationId,
    this.traceId,
  });

  final DateTime timestamp;
  final LogLevel level;
  final String code;
  final Map<String, Object?> attributes;
  final String? correlationId;
  final String? traceId;

  Map<String, Object?> toJson() => <String, Object?>{
    'timestamp': timestamp.toUtc().toIso8601String(),
    'level': level.name,
    'code': code,
    if (correlationId != null) 'correlationId': correlationId,
    if (traceId != null) 'traceId': traceId,
    'attributes': attributes,
  };
}

abstract interface class LogSink {
  FutureOr<void> write(LogEvent event);
}

final class RedactionPolicy {
  const RedactionPolicy({this.allowedAttributeKeys = _safeDefaults});

  static const Set<String> _safeDefaults = <String>{
    'appVersion',
    'attempt',
    'buildNumber',
    'durationMs',
    'entityType',
    'environment',
    'errorType',
    'fatal',
    'feature',
    'httpMethod',
    'operation',
    'platform',
    'queuedCount',
    'release',
    'routePattern',
    'schemaVersion',
    'source',
    'status',
    'statusCode',
    'syncPhase',
  };

  final Set<String> allowedAttributeKeys;

  Map<String, Object?> sanitize(Map<String, Object?> attributes) {
    return <String, Object?>{
      for (final entry in attributes.entries)
        if (allowedAttributeKeys.contains(entry.key))
          entry.key: _safeScalar(entry.value),
    };
  }

  Object? _safeScalar(Object? value) {
    if (value == null || value is num || value is bool) return value;
    if (value is String && value.length <= 128) return value;
    return '[redacted]';
  }
}

final class StructuredLogger {
  const StructuredLogger({
    required LogSink sink,
    required Clock clock,
    RedactionPolicy redaction = const RedactionPolicy(),
  }) : _sink = sink,
       _clock = clock,
       _redaction = redaction;

  final LogSink _sink;
  final Clock _clock;
  final RedactionPolicy _redaction;

  FutureOr<void> record(
    LogLevel level,
    String code, {
    Map<String, Object?> attributes = const <String, Object?>{},
    String? correlationId,
    String? traceId,
  }) {
    if (!_validCode(code)) throw ArgumentError.value(code, 'code');
    return _sink.write(
      LogEvent(
        timestamp: _clock.nowUtc(),
        level: level,
        code: code,
        attributes: _redaction.sanitize(attributes),
        correlationId: correlationId,
        traceId: traceId,
      ),
    );
  }

  bool _validCode(String code) =>
      RegExp(r'^[a-z][a-z0-9_.-]{2,63}$').hasMatch(code);
}

final class InMemoryLogSink implements LogSink {
  final List<LogEvent> events = <LogEvent>[];
  @override
  void write(LogEvent event) => events.add(event);

  String diagnosticExport() => const JsonEncoder.withIndent(
    '  ',
  ).convert(events.map((event) => event.toJson()).toList(growable: false));
}

abstract interface class Telemetry {
  FutureOr<void> counter(
    String name,
    int value,
    Map<String, Object?> attributes,
  );
  FutureOr<void> timing(
    String name,
    Duration duration,
    Map<String, Object?> attributes,
  );
  TelemetrySpan startSpan(String name, Map<String, Object?> attributes);
  FutureOr<void> deleteUserTelemetry();
}

abstract interface class TelemetrySpan {
  void setStatus(String status);
  FutureOr<void> end();
}

final class NoopTelemetry implements Telemetry {
  const NoopTelemetry();
  @override
  void counter(String name, int value, Map<String, Object?> attributes) {}
  @override
  void timing(
    String name,
    Duration duration,
    Map<String, Object?> attributes,
  ) {}
  @override
  TelemetrySpan startSpan(String name, Map<String, Object?> attributes) =>
      const _NoopSpan();
  @override
  void deleteUserTelemetry() {}
}

final class _NoopSpan implements TelemetrySpan {
  const _NoopSpan();
  @override
  void setStatus(String status) {}
  @override
  void end() {}
}

/// Writes events to the platform debug log (`dart:developer`), which shows in
/// IDE consoles and DevTools. Intended for development builds.
final class DebugLogSink implements LogSink {
  const DebugLogSink({this.minimumLevel = LogLevel.debug});

  final LogLevel minimumLevel;

  @override
  void write(LogEvent event) {
    if (event.level.index < minimumLevel.index) return;
    developer.log(
      jsonEncode(event.attributes),
      name: event.code,
      level: switch (event.level) {
        LogLevel.debug => 500,
        LogLevel.info => 800,
        LogLevel.warning => 900,
        LogLevel.error => 1000,
        LogLevel.critical => 1200,
      },
      time: event.timestamp,
    );
  }
}

/// Forwards each event to every sink. A failing sink never prevents delivery
/// to the others.
final class FanOutLogSink implements LogSink {
  FanOutLogSink(Iterable<LogSink> sinks)
    : _sinks = List<LogSink>.unmodifiable(sinks);

  final List<LogSink> _sinks;

  @override
  Future<void> write(LogEvent event) async {
    for (final sink in _sinks) {
      try {
        await sink.write(event);
      } on Object {
        // Logging must never crash the app.
      }
    }
  }
}

/// Port for crash/error reporting vendors (Sentry, Crashlytics, ...).
///
/// Implementations must scrub personal data from [error] messages and must
/// honour the user's reliability telemetry consent.
abstract interface class CrashReporter {
  Future<void> recordError(
    Object error,
    StackTrace? stackTrace, {
    required bool fatal,
    String? source,
  });
}

/// Records errors as structured log events without their messages, which
/// may contain personal data. Useful as a default and alongside a vendor.
final class LoggingCrashReporter implements CrashReporter {
  const LoggingCrashReporter(this._logger);

  final StructuredLogger _logger;

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stackTrace, {
    required bool fatal,
    String? source,
  }) async {
    await _logger.record(
      fatal ? LogLevel.critical : LogLevel.error,
      'app.uncaught_error',
      attributes: <String, Object?>{
        'errorType': error.runtimeType.toString(),
        'fatal': fatal,
        'source': ?source,
      },
    );
  }
}

/// Sends each error to every reporter; one failing reporter does not block
/// the others.
final class FanOutCrashReporter implements CrashReporter {
  FanOutCrashReporter(Iterable<CrashReporter> reporters)
    : _reporters = List<CrashReporter>.unmodifiable(reporters);

  final List<CrashReporter> _reporters;

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stackTrace, {
    required bool fatal,
    String? source,
  }) async {
    for (final reporter in _reporters) {
      try {
        await reporter.recordError(
          error,
          stackTrace,
          fatal: fatal,
          source: source,
        );
      } on Object {
        // Reporting must never crash the app.
      }
    }
  }
}
