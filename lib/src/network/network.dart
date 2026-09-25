import 'dart:async';

import '../testing/primitives.dart';

enum HttpMethod { get, post, put, patch, delete, head, options }

extension HttpMethodProperties on HttpMethod {
  bool get isNaturallyIdempotent => switch (this) {
    HttpMethod.get ||
    HttpMethod.put ||
    HttpMethod.delete ||
    HttpMethod.head ||
    HttpMethod.options => true,
    HttpMethod.post || HttpMethod.patch => false,
  };
}

final class CancellationToken {
  bool _cancelled = false;
  bool get isCancelled => _cancelled;
  void cancel() => _cancelled = true;
  void throwIfCancelled() {
    if (_cancelled) throw const RequestCancelled();
  }
}

final class RequestCancelled implements Exception {
  const RequestCancelled();
}

final class NetworkRequest {
  const NetworkRequest({
    required this.method,
    required this.uri,
    this.headers = const <String, String>{},
    this.body,
    this.idempotencyKey,
    this.timeout = const Duration(seconds: 30),
    this.cancellation,
  });

  final HttpMethod method;
  final Uri uri;
  final Map<String, String> headers;
  final Object? body;
  final String? idempotencyKey;
  final Duration timeout;
  final CancellationToken? cancellation;

  NetworkRequest copyWith({Map<String, String>? headers, Duration? timeout}) =>
      NetworkRequest(
        method: method,
        uri: uri,
        headers: headers ?? this.headers,
        body: body,
        idempotencyKey: idempotencyKey,
        timeout: timeout ?? this.timeout,
        cancellation: cancellation,
      );
}

final class NetworkResponse {
  const NetworkResponse({
    required this.statusCode,
    this.headers = const <String, String>{},
    this.body,
  });

  final int statusCode;
  final Map<String, String> headers;
  final Object? body;

  bool get isSuccess => statusCode >= 200 && statusCode < 300;
}

abstract interface class NetworkTransport {
  Future<NetworkResponse> send(NetworkRequest request);
}

abstract interface class AccessTokenProvider {
  Future<String?> accessToken();
}

abstract interface class LocaleProvider {
  String localeTag();
}

enum ApiFailureKind {
  offline,
  timeout,
  unauthorized,
  forbidden,
  conflict,
  validation,
  quota,
  server,
  upgradeRequired,
  cancelled,
  unknown,
}

final class ApiFailure implements Exception {
  const ApiFailure({
    required this.kind,
    required this.code,
    required this.message,
    required this.correlationId,
    required this.retryable,
    this.statusCode,
    this.details,
  });

  factory ApiFailure.fromResponse(
    NetworkResponse response, {
    required String fallbackCorrelationId,
  }) {
    final body = response.body;
    final json = body is Map<String, Object?>
        ? body
        : const <String, Object?>{};
    final correlationId = json['correlationId'] is String
        ? json['correlationId']! as String
        : response.headers['X-Correlation-ID'] ?? fallbackCorrelationId;
    final status = response.statusCode;
    final kind = switch (status) {
      401 => ApiFailureKind.unauthorized,
      403 => ApiFailureKind.forbidden,
      409 => ApiFailureKind.conflict,
      422 => ApiFailureKind.validation,
      426 => ApiFailureKind.upgradeRequired,
      429 => ApiFailureKind.quota,
      >= 500 => ApiFailureKind.server,
      _ => ApiFailureKind.unknown,
    };
    final retryable = json['retryable'] is bool
        ? json['retryable']! as bool
        : status == 429 || status >= 500;
    return ApiFailure(
      kind: kind,
      code: json['code'] is String ? json['code']! as String : 'http_$status',
      message: json['message'] is String
          ? json['message']! as String
          : 'The request could not be completed.',
      correlationId: correlationId,
      retryable: retryable,
      statusCode: status,
      details: json['details'] is Map<String, Object?>
          ? json['details']! as Map<String, Object?>
          : null,
    );
  }

  final ApiFailureKind kind;
  final String code;
  final String message;
  final String correlationId;
  final bool retryable;
  final int? statusCode;
  final Map<String, Object?>? details;

  Map<String, Object?> toJson() => <String, Object?>{
    'code': code,
    'message': message,
    'correlationId': correlationId,
    if (details != null) 'details': details,
    'retryable': retryable,
  };
}

abstract interface class Delay {
  Future<void> wait(Duration duration);
}

final class TimerDelay implements Delay {
  const TimerDelay();

  @override
  Future<void> wait(Duration duration) => Future<void>.delayed(duration);
}

abstract interface class JitterSource {
  double nextUnit();
}

final class NoJitter implements JitterSource {
  const NoJitter();
  @override
  double nextUnit() => 0.5;
}

final class RetryPolicy {
  const RetryPolicy({
    this.maxAttempts = 3,
    this.baseDelay = const Duration(milliseconds: 250),
    this.maximumDelay = const Duration(seconds: 8),
  }) : assert(maxAttempts > 0);

  final int maxAttempts;
  final Duration baseDelay;
  final Duration maximumDelay;

  bool mayRetry(NetworkRequest request, ApiFailure failure, int attempt) {
    final safeWrite =
        request.method.isNaturallyIdempotent ||
        (request.idempotencyKey?.isNotEmpty ?? false);
    return attempt < maxAttempts && safeWrite && failure.retryable;
  }

  Duration delayFor(int attempt, JitterSource jitter) {
    final multiplier = 1 << (attempt - 1).clamp(0, 20).toInt();
    final raw = baseDelay.inMilliseconds * multiplier;
    final capped = raw.clamp(0, maximumDelay.inMilliseconds);
    final factor = 0.75 + (jitter.nextUnit().clamp(0, 1) * 0.5);
    return Duration(milliseconds: (capped * factor).round());
  }
}

final class NetworkClient {
  NetworkClient({
    required NetworkTransport transport,
    required IdGenerator ids,
    this.accessTokens,
    this.locales,
    this.appVersion,
    this.retryPolicy = const RetryPolicy(),
    this.delay = const TimerDelay(),
    this.jitter = const NoJitter(),
  }) : _transport = transport,
       _ids = ids;

  final NetworkTransport _transport;
  final IdGenerator _ids;
  final AccessTokenProvider? accessTokens;
  final LocaleProvider? locales;
  final String? appVersion;
  final RetryPolicy retryPolicy;
  final Delay delay;
  final JitterSource jitter;

  Future<NetworkResponse> send(NetworkRequest request) async {
    final correlationId = request.headers['X-Correlation-ID'] ?? _ids.next();
    final token = await accessTokens?.accessToken();
    final effective = request.copyWith(
      headers: <String, String>{
        ...request.headers,
        'X-Correlation-ID': correlationId,
        if (request.idempotencyKey case final key?) 'Idempotency-Key': key,
        if (token != null) 'Authorization': 'Bearer $token',
        if (locales != null) 'Accept-Language': locales!.localeTag(),
        if (appVersion != null) 'X-App-Version': appVersion!,
      },
    );

    for (var attempt = 1; attempt <= retryPolicy.maxAttempts; attempt++) {
      effective.cancellation?.throwIfCancelled();
      try {
        final response = await _transport
            .send(effective)
            .timeout(
              effective.timeout,
              onTimeout: () => throw ApiFailure(
                kind: ApiFailureKind.timeout,
                code: 'request_timeout',
                message: 'The request timed out.',
                correlationId: correlationId,
                retryable: true,
              ),
            );
        if (response.isSuccess) return response;
        final failure = ApiFailure.fromResponse(
          response,
          fallbackCorrelationId: correlationId,
        );
        if (!retryPolicy.mayRetry(effective, failure, attempt)) throw failure;
        await delay.wait(retryPolicy.delayFor(attempt, jitter));
      } on RequestCancelled {
        throw ApiFailure(
          kind: ApiFailureKind.cancelled,
          code: 'request_cancelled',
          message: 'The request was cancelled.',
          correlationId: correlationId,
          retryable: false,
        );
      } on ApiFailure catch (failure) {
        if (!retryPolicy.mayRetry(effective, failure, attempt)) rethrow;
        await delay.wait(retryPolicy.delayFor(attempt, jitter));
      }
    }
    throw StateError('Retry loop ended unexpectedly.');
  }
}
