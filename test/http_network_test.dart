import 'dart:async';
import 'dart:convert';

import 'package:flutter_app_foundation/flutter_app_foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

void main() {
  group('NetworkClient', () {
    test('resolves paths under the base URI with query parameters', () {
      final client = NetworkClient(
        transport: ScriptedNetworkTransport(const <Object>[]),
        ids: SequentialIdGenerator(),
        baseUri: Uri.parse('https://api.example.test/v1'),
      );
      expect(
        client.resolve('items', query: <String, String>{'page': '2'}),
        Uri.parse('https://api.example.test/v1/items?page=2'),
      );
      expect(
        client.resolve('/items/7?expand=true'),
        Uri.parse('https://api.example.test/v1/items/7?expand=true'),
      );
      expect(
        client.resolve('https://other.example.test/x'),
        Uri.parse('https://other.example.test/x'),
      );
    });

    test('decodes JSON through a typed decoder', () async {
      final transport = ScriptedNetworkTransport(<Object>[
        const NetworkResponse(
          statusCode: 200,
          body: <String, Object?>{'id': 'a', 'count': 3},
        ),
      ]);
      final client = NetworkClient(
        transport: transport,
        ids: SequentialIdGenerator(),
        baseUri: Uri.parse('https://api.example.test'),
        defaultHeaders: const <String, String>{'X-Client': 'test'},
      );
      final count = await client.getJson<int>(
        'items/a',
        decode: (json) => (json! as Map<String, Object?>)['count']! as int,
      );
      expect(count, 3);
      final sent = transport.requests.single;
      expect(sent.uri.toString(), 'https://api.example.test/items/a');
      expect(sent.headers['Accept'], 'application/json');
      expect(sent.headers['X-Client'], 'test');
    });

    test('decoder errors become invalid_response failures', () async {
      final client = NetworkClient(
        transport: ScriptedNetworkTransport(<Object>[
          const NetworkResponse(statusCode: 200, body: 'not json'),
        ]),
        ids: SequentialIdGenerator(prefix: 'c'),
        baseUri: Uri.parse('https://api.example.test'),
      );
      await expectLater(
        client.getJson<Map<String, Object?>>('x'),
        throwsA(
          isA<ApiFailure>()
              .having((f) => f.code, 'code', 'invalid_response')
              .having((f) => f.correlationId, 'correlationId', 'c-1'),
        ),
      );
    });

    test('maps 404 and reads headers case-insensitively', () {
      final failure = ApiFailure.fromResponse(
        const NetworkResponse(
          statusCode: 404,
          headers: <String, String>{'x-correlation-id': 'server-1'},
        ),
        fallbackCorrelationId: 'fallback',
      );
      expect(failure.kind, ApiFailureKind.notFound);
      expect(failure.correlationId, 'server-1');
      expect(failure.retryable, isFalse);
    });

    test('honours Retry-After within the policy maximum', () async {
      final delay = RecordingDelay();
      final client = NetworkClient(
        transport: ScriptedNetworkTransport(<Object>[
          const NetworkResponse(
            statusCode: 429,
            headers: <String, String>{'retry-after': '3'},
          ),
          const NetworkResponse(statusCode: 200),
        ]),
        ids: SequentialIdGenerator(),
        delay: delay,
      );
      await client.send(
        NetworkRequest(
          method: HttpMethod.get,
          uri: Uri.parse('https://api.example.test/x'),
        ),
      );
      expect(delay.waits, <Duration>[const Duration(seconds: 3)]);
    });

    test('does not retry when Retry-After exceeds the policy', () async {
      final transport = ScriptedNetworkTransport(<Object>[
        const NetworkResponse(
          statusCode: 503,
          headers: <String, String>{'Retry-After': '3600'},
        ),
      ]);
      final client = NetworkClient(
        transport: transport,
        ids: SequentialIdGenerator(),
        delay: RecordingDelay(),
      );
      await expectLater(
        client.send(
          NetworkRequest(
            method: HttpMethod.get,
            uri: Uri.parse('https://api.example.test/x'),
          ),
        ),
        throwsA(
          isA<ApiFailure>().having(
            (f) => f.retryAfter,
            'retryAfter',
            const Duration(hours: 1),
          ),
        ),
      );
      expect(transport.requests, hasLength(1));
    });

    test('refreshes the token once and replays on 401', () async {
      final transport = ScriptedNetworkTransport(<Object>[
        const NetworkResponse(statusCode: 401),
        const NetworkResponse(statusCode: 200),
      ]);
      final tokens = _Tokens();
      final client = NetworkClient(
        transport: transport,
        ids: SequentialIdGenerator(),
        accessTokens: tokens,
        delay: RecordingDelay(),
      );
      await client.send(
        NetworkRequest(
          method: HttpMethod.post,
          uri: Uri.parse('https://api.example.test/x'),
        ),
      );
      expect(tokens.refreshes, 1);
      expect(
        transport.requests.map((r) => r.headers['Authorization']),
        <String?>['Bearer old', 'Bearer new'],
      );
    });

    test('does not loop when the refreshed token is also rejected', () async {
      final transport = ScriptedNetworkTransport(<Object>[
        const NetworkResponse(statusCode: 401),
        const NetworkResponse(statusCode: 401),
      ]);
      final tokens = _Tokens();
      final client = NetworkClient(
        transport: transport,
        ids: SequentialIdGenerator(),
        accessTokens: tokens,
      );
      await expectLater(
        client.send(
          NetworkRequest(
            method: HttpMethod.get,
            uri: Uri.parse('https://api.example.test/x'),
          ),
        ),
        throwsA(
          isA<ApiFailure>().having(
            (f) => f.kind,
            'kind',
            ApiFailureKind.unauthorized,
          ),
        ),
      );
      expect(tokens.refreshes, 1);
      expect(transport.requests, hasLength(2));
    });

    test('cancelled requests fail fast without sending', () async {
      final transport = ScriptedNetworkTransport(const <Object>[]);
      final token = CancellationToken()..cancel();
      final client = NetworkClient(
        transport: transport,
        ids: SequentialIdGenerator(),
      );
      await expectLater(
        client.send(
          NetworkRequest(
            method: HttpMethod.get,
            uri: Uri.parse('https://api.example.test/x'),
            cancellation: token,
          ),
        ),
        throwsA(
          isA<ApiFailure>().having(
            (f) => f.kind,
            'kind',
            ApiFailureKind.cancelled,
          ),
        ),
      );
      expect(transport.requests, isEmpty);
    });
  });

  group('HttpNetworkTransport', () {
    test('encodes JSON bodies and decodes JSON responses', () async {
      late http.BaseRequest seen;
      String? seenBody;
      final transport = HttpNetworkTransport(
        client: MockClient((request) async {
          seen = request;
          seenBody = request.body;
          return http.Response(
            jsonEncode(<String, Object?>{'ok': true, 'name': 'Zoë'}),
            201,
            headers: <String, String>{
              'content-type': 'application/json; charset=utf-8',
            },
          );
        }),
      );
      final response = await transport.send(
        NetworkRequest(
          method: HttpMethod.post,
          uri: Uri.parse('https://api.example.test/items'),
          headers: const <String, String>{'X-Correlation-ID': 'c-1'},
          body: const <String, Object?>{'title': 'Buy milk'},
        ),
      );
      expect(seen.method, 'POST');
      expect(seen.headers['Content-Type'], startsWith('application/json'));
      expect(jsonDecode(seenBody!), <String, Object?>{'title': 'Buy milk'});
      expect(response.statusCode, 201);
      expect(response.body, <String, Object?>{'ok': true, 'name': 'Zoë'});
    });

    test('returns text and empty bodies faithfully', () async {
      final transport = HttpNetworkTransport(
        client: MockClient(
          (request) async => request.url.path == '/empty'
              ? http.Response('', 204)
              : http.Response(
                  'hello',
                  200,
                  headers: <String, String>{'content-type': 'text/plain'},
                ),
        ),
      );
      Future<Object?> body(String path) async => (await transport.send(
        NetworkRequest(
          method: HttpMethod.get,
          uri: Uri.parse('https://api.example.test$path'),
        ),
      )).body;
      expect(await body('/text'), 'hello');
      expect(await body('/empty'), isNull);
    });

    test('maps connection errors to offline failures', () async {
      final transport = HttpNetworkTransport(
        client: MockClient(
          (request) async => throw http.ClientException('no route'),
        ),
      );
      await expectLater(
        transport.send(
          NetworkRequest(
            method: HttpMethod.get,
            uri: Uri.parse('https://api.example.test/x'),
            headers: const <String, String>{'X-Correlation-ID': 'c-9'},
          ),
        ),
        throwsA(
          isA<ApiFailure>()
              .having((f) => f.kind, 'kind', ApiFailureKind.offline)
              .having((f) => f.retryable, 'retryable', isTrue)
              .having((f) => f.correlationId, 'correlationId', 'c-9'),
        ),
      );
    });

    test('aborts in-flight requests on timeout and cancellation', () async {
      final transport = HttpNetworkTransport(
        client: MockClient.streaming(
          (request, body) => Completer<http.StreamedResponse>().future,
        ),
      );
      await expectLater(
        transport.send(
          NetworkRequest(
            method: HttpMethod.get,
            uri: Uri.parse('https://api.example.test/slow'),
            timeout: const Duration(milliseconds: 20),
          ),
        ),
        throwsA(
          isA<ApiFailure>().having((f) => f.code, 'code', 'request_timeout'),
        ),
      );

      final cancellation = CancellationToken();
      final pending = transport.send(
        NetworkRequest(
          method: HttpMethod.get,
          uri: Uri.parse('https://api.example.test/slow'),
          cancellation: cancellation,
        ),
      );
      cancellation.cancel();
      await expectLater(pending, throwsA(isA<RequestCancelled>()));
    });

    test('works end to end through NetworkClient', () async {
      final transport = HttpNetworkTransport(
        client: MockClient(
          (request) async => http.Response(
            jsonEncode(<String, Object?>{
              'code': 'title_required',
              'message': 'Add a title.',
              'retryable': false,
            }),
            422,
            headers: <String, String>{'content-type': 'application/json'},
          ),
        ),
      );
      final client = NetworkClient(
        transport: transport,
        ids: SequentialIdGenerator(),
        baseUri: Uri.parse('https://api.example.test'),
      );
      await expectLater(
        client.postJson<Object?>('items', body: const <String, Object?>{}),
        throwsA(
          isA<ApiFailure>()
              .having((f) => f.kind, 'kind', ApiFailureKind.validation)
              .having((f) => f.message, 'message', 'Add a title.'),
        ),
      );
    });
  });
}

final class _Tokens implements RefreshableAccessTokenProvider {
  var current = 'old';
  var refreshes = 0;

  @override
  Future<String?> accessToken() async => current;

  @override
  Future<String?> refreshAccessToken() async {
    refreshes++;
    return current = 'new';
  }
}
