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
  final Completer<void> _cancelled = Completer<void>();

  bool get isCancelled => _cancelled.isCompleted;

  /// Completes when [cancel] is called, so transports can abort in-flight I/O.
  Future<void> get whenCancelled => _cancelled.future;

  void cancel() {
    if (!_cancelled.isCompleted) _cancelled.complete();
  }

  void throwIfCancelled() {
    if (isCancelled) throw const RequestCancelled();
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

  NetworkRequest copyWith({
    Uri? uri,
    Map<String, String>? headers,
    Duration? timeout,
  }) => NetworkRequest(
    method: method,
    uri: uri ?? this.uri,
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

  /// Case-insensitive header lookup; HTTP header names are case-insensitive
  /// and most clients normalise them to lower case.
  String? header(String name) => headerValue(headers, name);
}

String? headerValue(Map<String, String> headers, String name) {
  final direct = headers[name];
  if (direct != null) return direct;
  final lower = name.toLowerCase();
  for (final entry in headers.entries) {
    if (entry.key.toLowerCase() == lower) return entry.value;
  }
  return null;
}

abstract interface class NetworkTransport {
  Future<NetworkResponse> send(NetworkRequest request);
}

abstract interface class AccessTokenProvider {
  Future<String?> accessToken();
}

/// An [AccessTokenProvider] that can obtain a new token after the server
/// rejects the current one with `401 Unauthorized`.
///
/// [NetworkClient] calls [refreshAccessToken] at most once per request and
/// replays the request with the new token when one is returned.
abstract interface class RefreshableAccessTokenProvider
    implements AccessTokenProvider {
  Future<String?> refreshAccessToken();
}

abstract interface class LocaleProvider {
  String localeTag();
}

enum ApiFailureKind {
  offline,
  timeout,
  unauthorized,
  forbidden,
  notFound,
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
    this.retryAfter,
  });

  /// Failure for a transport that could not reach the server at all.
  factory ApiFailure.offline({
    required String correlationId,
    String code = 'network_unreachable',
  }) => ApiFailure(
    kind: ApiFailureKind.offline,
    code: code,
    message: 'The server could not be reached. Check the connection.',
    correlationId: correlationId,
    retryable: true,
  );

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
        : response.header('X-Correlation-ID') ?? fallbackCorrelationId;
    final status = response.statusCode;
    final kind = switch (status) {
      400 || 422 => ApiFailureKind.validation,
      401 => ApiFailureKind.unauthorized,
      403 => ApiFailureKind.forbidden,
      404 || 410 => ApiFailureKind.notFound,
      408 => ApiFailureKind.timeout,
      409 || 412 => ApiFailureKind.conflict,
      426 => ApiFailureKind.upgradeRequired,
      429 => ApiFailureKind.quota,
      >= 500 => ApiFailureKind.server,
      _ => ApiFailureKind.unknown,
    };
    final retryable = json['retryable'] is bool
        ? json['retryable']! as bool
        : status == 408 || status == 429 || status >= 500;
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
      retryAfter: _parseRetryAfter(response.header('Retry-After')),
    );
  }

  static Duration? _parseRetryAfter(String? value) {
    if (value == null) return null;
    final seconds = int.tryParse(value.trim());
    if (seconds != null) return Duration(seconds: seconds < 0 ? 0 : seconds);
    // HTTP-date form is not supported without a clock; callers fall back to
    // the policy's exponential backoff.
    return null;
  }

  final ApiFailureKind kind;
  final String code;
  final String message;
  final String correlationId;
  final bool retryable;
  final int? statusCode;
  final Map<String, Object?>? details;

  /// Server-requested wait from a `Retry-After` header, when present.
  final Duration? retryAfter;

  @override
  String toString() =>
      'ApiFailure(${kind.name}, $code, status: $statusCode, '
      'correlationId: $correlationId)';

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

  /// Delay before the next attempt, honouring a server `Retry-After` when it
  /// is within [maximumDelay]. Returns null when the server asks for a longer
  /// wait than this policy allows, meaning the request should not be retried.
  Duration? delayAfter(ApiFailure failure, int attempt, JitterSource jitter) {
    final requested = failure.retryAfter;
    if (requested == null) return delayFor(attempt, jitter);
    return requested <= maximumDelay ? requested : null;
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
    this.baseUri,
    this.defaultHeaders = const <String, String>{},
    this.accessTokens,
    this.locales,
    this.appVersion,
    this.retryPolicy = const RetryPolicy(),
    this.delay = const TimerDelay(),
    this.jitter = const NoJitter(),
  }) : assert(
         baseUri == null || (baseUri.hasScheme && baseUri.hasAuthority),
         'baseUri must be absolute.',
       ),
       _transport = transport,
       _ids = ids;

  final NetworkTransport _transport;
  final IdGenerator _ids;

  /// Relative request URIs are resolved against this base.
  final Uri? baseUri;

  /// Headers applied to every request; per-request headers take precedence.
  final Map<String, String> defaultHeaders;
  final AccessTokenProvider? accessTokens;
  final LocaleProvider? locales;
  final String? appVersion;
  final RetryPolicy retryPolicy;
  final Delay delay;
  final JitterSource jitter;

  /// Resolves [path] (which may include a query) against [baseUri].
  ///
  /// The base path is treated as a directory prefix, so with a base of
  /// `https://api.example.com/v1` both `items` and `/items` resolve to
  /// `https://api.example.com/v1/items`. Absolute URIs are returned unchanged.
  Uri resolve(String path, {Map<String, String>? query}) {
    final relative = Uri.parse(path);
    final base = baseUri;
    var resolved = relative;
    if (!relative.hasScheme && base != null) {
      final prefix = base.path.endsWith('/') ? base.path : '${base.path}/';
      final suffix = relative.path.startsWith('/')
          ? relative.path.substring(1)
          : relative.path;
      resolved = Uri(
        scheme: base.scheme,
        userInfo: base.userInfo,
        host: base.host,
        port: base.hasPort ? base.port : null,
        path: '$prefix$suffix',
        query: relative.hasQuery ? relative.query : null,
      );
    }
    if (query == null || query.isEmpty) return resolved;
    return resolved.replace(
      queryParameters: <String, String>{...resolved.queryParameters, ...query},
    );
  }

  Future<NetworkResponse> send(NetworkRequest request) async {
    final correlationId =
        headerValue(request.headers, 'X-Correlation-ID') ?? _ids.next();
    final uri = request.uri.hasScheme ? request.uri : resolve('${request.uri}');
    if (!uri.hasScheme) {
      throw ArgumentError.value(
        request.uri,
        'request.uri',
        'Relative URI without a NetworkClient.baseUri.',
      );
    }
    final base = request.copyWith(
      uri: uri,
      headers: <String, String>{
        ...defaultHeaders,
        ...request.headers,
        'X-Correlation-ID': correlationId,
        if (request.idempotencyKey case final key?) 'Idempotency-Key': key,
        if (locales != null) 'Accept-Language': locales!.localeTag(),
        if (appVersion != null) 'X-App-Version': appVersion!,
      },
    );

    var token = await accessTokens?.accessToken();
    var refreshedToken = false;
    for (var attempt = 1; attempt <= retryPolicy.maxAttempts; attempt++) {
      final effective = token == null
          ? base
          : base.copyWith(
              headers: <String, String>{
                ...base.headers,
                'Authorization': 'Bearer $token',
              },
            );
      try {
        effective.cancellation?.throwIfCancelled();
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
        throw ApiFailure.fromResponse(
          response,
          fallbackCorrelationId: correlationId,
        );
      } on RequestCancelled {
        throw ApiFailure(
          kind: ApiFailureKind.cancelled,
          code: 'request_cancelled',
          message: 'The request was cancelled.',
          correlationId: correlationId,
          retryable: false,
        );
      } on ApiFailure catch (failure) {
        final tokens = accessTokens;
        if (failure.kind == ApiFailureKind.unauthorized &&
            token != null &&
            !refreshedToken &&
            tokens is RefreshableAccessTokenProvider) {
          refreshedToken = true;
          final next = await tokens.refreshAccessToken();
          if (next != null && next != token) {
            token = next;
            // A token replay does not consume a retry attempt.
            attempt--;
            continue;
          }
        }
        if (!retryPolicy.mayRetry(effective, failure, attempt)) rethrow;
        final wait = retryPolicy.delayAfter(failure, attempt, jitter);
        if (wait == null) rethrow;
        await delay.wait(wait);
      }
    }
    throw StateError('Retry loop ended unexpectedly.');
  }

  /// Sends a JSON request and decodes the response body.
  ///
  /// [decode] converts the decoded JSON (`Map`, `List`, scalar, or null for an
  /// empty body) into a typed value. When omitted the JSON is cast to [T].
  /// Decoding errors surface as an [ApiFailure] with code `invalid_response`.
  Future<T> requestJson<T>(
    HttpMethod method,
    String path, {
    Object? body,
    Map<String, String>? query,
    Map<String, String> headers = const <String, String>{},
    String? idempotencyKey,
    T Function(Object? json)? decode,
    CancellationToken? cancellation,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final correlationId =
        headerValue(headers, 'X-Correlation-ID') ?? _ids.next();
    final response = await send(
      NetworkRequest(
        method: method,
        uri: resolve(path, query: query),
        headers: <String, String>{
          'Accept': 'application/json',
          ...headers,
          'X-Correlation-ID': correlationId,
        },
        body: body,
        idempotencyKey: idempotencyKey,
        timeout: timeout,
        cancellation: cancellation,
      ),
    );
    try {
      return decode == null ? response.body as T : decode(response.body);
    } on Object catch (error) {
      if (error is ApiFailure) rethrow;
      throw ApiFailure(
        kind: ApiFailureKind.unknown,
        code: 'invalid_response',
        message: 'The server response could not be read.',
        correlationId: correlationId,
        retryable: false,
        statusCode: response.statusCode,
      );
    }
  }

  Future<T> getJson<T>(
    String path, {
    Map<String, String>? query,
    Map<String, String> headers = const <String, String>{},
    T Function(Object? json)? decode,
    CancellationToken? cancellation,
  }) => requestJson<T>(
    HttpMethod.get,
    path,
    query: query,
    headers: headers,
    decode: decode,
    cancellation: cancellation,
  );

  /// POST is retried only when [idempotencyKey] is supplied.
  Future<T> postJson<T>(
    String path, {
    Object? body,
    String? idempotencyKey,
    Map<String, String> headers = const <String, String>{},
    T Function(Object? json)? decode,
    CancellationToken? cancellation,
  }) => requestJson<T>(
    HttpMethod.post,
    path,
    body: body,
    idempotencyKey: idempotencyKey,
    headers: headers,
    decode: decode,
    cancellation: cancellation,
  );

  Future<T> putJson<T>(
    String path, {
    Object? body,
    Map<String, String> headers = const <String, String>{},
    T Function(Object? json)? decode,
    CancellationToken? cancellation,
  }) => requestJson<T>(
    HttpMethod.put,
    path,
    body: body,
    headers: headers,
    decode: decode,
    cancellation: cancellation,
  );

  /// PATCH is retried only when [idempotencyKey] is supplied.
  Future<T> patchJson<T>(
    String path, {
    Object? body,
    String? idempotencyKey,
    Map<String, String> headers = const <String, String>{},
    T Function(Object? json)? decode,
    CancellationToken? cancellation,
  }) => requestJson<T>(
    HttpMethod.patch,
    path,
    body: body,
    idempotencyKey: idempotencyKey,
    headers: headers,
    decode: decode,
    cancellation: cancellation,
  );

  Future<void> delete(
    String path, {
    Map<String, String>? query,
    Map<String, String> headers = const <String, String>{},
    CancellationToken? cancellation,
  }) => requestJson<Object?>(
    HttpMethod.delete,
    path,
    query: query,
    headers: headers,
    cancellation: cancellation,
  );
}
