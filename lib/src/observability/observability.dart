import 'dart:async';
import 'dart:convert';

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
  const RedactionPolicy({
    this.allowedAttributeKeys = _safeDefaults,
  });

  static const Set<String> _safeDefaults = <String>{
    'appVersion',
    'attempt',
    'buildNumber',
    'durationMs',
    'entityType',
    'environment',
    'feature',
    'httpMethod',
    'operation',
    'platform',
    'queuedCount',
    'release',
    'routePattern',
    'schemaVersion',
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
  })  : _sink = sink,
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
    return _sink.write(LogEvent(
      timestamp: _clock.nowUtc(),
      level: level,
      code: code,
      attributes: _redaction.sanitize(attributes),
      correlationId: correlationId,
      traceId: traceId,
    ));
  }

  bool _validCode(String code) =>
      RegExp(r'^[a-z][a-z0-9_.-]{2,63}$').hasMatch(code);
}

final class InMemoryLogSink implements LogSink {
  final List<LogEvent> events = <LogEvent>[];
  @override
  void write(LogEvent event) => events.add(event);

  String diagnosticExport() => const JsonEncoder.withIndent('  ').convert(
        events.map((event) => event.toJson()).toList(growable: false),
      );
}

abstract interface class Telemetry {
  FutureOr<void> counter(String name, int value, Map<String, Object?> attributes);
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
  void timing(String name, Duration duration, Map<String, Object?> attributes) {}
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
