import 'package:flutter_app_foundation/flutter_app_foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('client adds shared correlation and idempotency headers', () async {
    final transport = ScriptedNetworkTransport(<Object>[
      const NetworkResponse(statusCode: 204),
    ]);
    final client = NetworkClient(
      transport: transport,
      ids: SequentialIdGenerator(prefix: 'correlation'),
    );

    await client.send(NetworkRequest(
      method: HttpMethod.post,
      uri: Uri.parse('https://api.example.test/mutations'),
      idempotencyKey: 'mutation-1',
    ));

    expect(transport.requests.single.headers['X-Correlation-ID'], 'correlation-1');
    expect(transport.requests.single.headers['Idempotency-Key'], 'mutation-1');
  });

  test('idempotent failure retries and preserves correlation ID', () async {
    final transport = ScriptedNetworkTransport(<Object>[
      const NetworkResponse(statusCode: 503),
      const NetworkResponse(statusCode: 200),
    ]);
    final delay = RecordingDelay();
    final client = NetworkClient(
      transport: transport,
      ids: SequentialIdGenerator(prefix: 'request'),
      delay: delay,
    );

    final result = await client.send(NetworkRequest(
      method: HttpMethod.get,
      uri: Uri.parse('https://api.example.test/items'),
    ));

    expect(result.statusCode, 200);
    expect(transport.requests, hasLength(2));
    expect(delay.waits, hasLength(1));
    expect(
      transport.requests[0].headers['X-Correlation-ID'],
      transport.requests[1].headers['X-Correlation-ID'],
    );
  });

  test('non-idempotent POST is not retried without key', () async {
    final transport = ScriptedNetworkTransport(<Object>[
      const NetworkResponse(statusCode: 503),
      const NetworkResponse(statusCode: 200),
    ]);
    final client = NetworkClient(
      transport: transport,
      ids: SequentialIdGenerator(),
      delay: RecordingDelay(),
    );

    await expectLater(
      client.send(NetworkRequest(
        method: HttpMethod.post,
        uri: Uri.parse('https://api.example.test/items'),
      )),
      throwsA(isA<ApiFailure>()),
    );
    expect(transport.requests, hasLength(1));
  });

  test('normalized error preserves contract fields', () {
    final failure = ApiFailure.fromResponse(
      const NetworkResponse(
        statusCode: 422,
        body: <String, Object?>{
          'code': 'invalid_input',
          'message': 'Review the fields.',
          'correlationId': 'c-1',
          'retryable': false,
        },
      ),
      fallbackCorrelationId: 'fallback',
    );
    expect(failure.toJson(), <String, Object?>{
      'code': 'invalid_input',
      'message': 'Review the fields.',
      'correlationId': 'c-1',
      'retryable': false,
    });
  });
}
