import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import 'network.dart';

/// Production [NetworkTransport] built on `package:http`.
///
/// Works on every Flutter platform, including web. Request bodies are encoded
/// by type: `null` sends nothing, a `String` is sent as UTF-8 text, a
/// `List<int>` as raw bytes, and anything else as JSON. Responses whose
/// content type is JSON are decoded to Dart objects, `text/*` to a `String`,
/// and anything else to [Uint8List].
///
/// Connection failures become [ApiFailureKind.offline] failures, timeouts and
/// cancellations abort the underlying request instead of leaking it.
final class HttpNetworkTransport implements NetworkTransport {
  HttpNetworkTransport({http.Client? client})
    : _client = client ?? http.Client(),
      _ownsClient = client == null;

  final http.Client _client;
  final bool _ownsClient;

  @override
  Future<NetworkResponse> send(NetworkRequest request) async {
    final correlationId =
        headerValue(request.headers, 'X-Correlation-ID') ?? 'unassigned';
    final abort = Completer<void>();
    var timedOut = false;
    final timer = Timer(request.timeout, () {
      timedOut = true;
      if (!abort.isCompleted) abort.complete();
    });
    unawaited(
      request.cancellation?.whenCancelled.then((_) {
        if (!abort.isCompleted) abort.complete();
      }),
    );

    final outgoing = http.AbortableRequest(
      request.method.name.toUpperCase(),
      request.uri,
      abortTrigger: abort.future,
    )..headers.addAll(request.headers);
    _encodeBody(outgoing, request.body);

    try {
      // Race the abort signal as well, so clients that ignore abort triggers
      // still cannot hang the caller.
      final response = await Future.any<http.Response>(<Future<http.Response>>[
        _client.send(outgoing).then(http.Response.fromStream),
        abort.future.then<http.Response>((_) => throw const _Aborted()),
      ]);
      return NetworkResponse(
        statusCode: response.statusCode,
        headers: response.headers,
        body: _decodeBody(response),
      );
    } on _Aborted {
      throw _abortFailure(request, correlationId, timedOut: timedOut);
    } on http.RequestAbortedException {
      throw _abortFailure(request, correlationId, timedOut: timedOut);
    } on http.ClientException {
      throw ApiFailure.offline(correlationId: correlationId);
    } finally {
      timer.cancel();
      if (!abort.isCompleted) abort.complete();
    }
  }

  static Exception _abortFailure(
    NetworkRequest request,
    String correlationId, {
    required bool timedOut,
  }) {
    if (request.cancellation?.isCancelled ?? false) {
      return const RequestCancelled();
    }
    return ApiFailure(
      kind: ApiFailureKind.timeout,
      code: timedOut ? 'request_timeout' : 'request_aborted',
      message: 'The request timed out.',
      correlationId: correlationId,
      retryable: true,
    );
  }

  /// Closes the underlying client when this transport created it.
  void close() {
    if (_ownsClient) _client.close();
  }

  static void _encodeBody(http.Request request, Object? body) {
    switch (body) {
      case null:
        return;
      case final String text:
        request.headers.putIfAbsent(
          'Content-Type',
          () => 'text/plain; charset=utf-8',
        );
        request.bodyBytes = utf8.encode(text);
      case final List<int> bytes:
        request.headers.putIfAbsent(
          'Content-Type',
          () => 'application/octet-stream',
        );
        request.bodyBytes = bytes;
      default:
        request.headers.putIfAbsent(
          'Content-Type',
          () => 'application/json; charset=utf-8',
        );
        request.bodyBytes = utf8.encode(jsonEncode(body));
    }
  }

  static Object? _decodeBody(http.Response response) {
    final bytes = response.bodyBytes;
    if (bytes.isEmpty) return null;
    final type = (response.headers['content-type'] ?? '').toLowerCase();
    if (type.contains('json')) {
      final text = utf8.decode(bytes, allowMalformed: true);
      try {
        return jsonDecode(text);
      } on FormatException {
        return text;
      }
    }
    if (type.startsWith('text/') || type.isEmpty) {
      return utf8.decode(bytes, allowMalformed: true);
    }
    return Uint8List.fromList(bytes);
  }
}

final class _Aborted implements Exception {
  const _Aborted();
}
