import 'package:flutter_app_foundation/flutter_app_foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  AuthTokens tokens(String access, DateTime expiry) => AuthTokens(
    accessToken: access,
    refreshToken: 'refresh-$access',
    accessTokenExpiresAt: expiry,
  );

  group('PKCE', () {
    test('matches the RFC 7636 S256 test vector', () {
      expect(
        pkceS256Challenge('dBjftJeZ4CVP-mB92K27uhbUJU1p1r_wW1gFWFOEjXk'),
        'E9Melhoa2OwvFrEMTJguCHaoeK1t8URWbuGJSstw-cM',
      );
    });

    test('builds a complete authorization URL without the verifier', () {
      final request = OidcAuthorizationRequest.withPkce(
        authorizationEndpoint: Uri.parse('https://id.example.test/authorize'),
        clientId: 'mobile',
        redirectUri: Uri.parse('com.example.app:/callback'),
      );
      final params = request.authorizationUri.queryParameters;
      expect(params['response_type'], 'code');
      expect(params['client_id'], 'mobile');
      expect(params['code_challenge_method'], 'S256');
      expect(
        params['code_challenge'],
        pkceS256Challenge(request.codeVerifier!),
      );
      expect(params['scope'], 'openid profile offline_access');
      expect(params.values, isNot(contains(request.codeVerifier)));
      expect(request.state, isNot(request.nonce));
    });

    test('validates redirect state and provider errors', () {
      final request = OidcAuthorizationRequest.withPkce(
        authorizationEndpoint: Uri.parse('https://id.example.test/authorize'),
        clientId: 'mobile',
        redirectUri: Uri.parse('com.example.app:/callback'),
      );
      final ok = Uri.parse(
        'com.example.app:/callback?code=abc&state=${request.state}',
      );
      expect(request.authorizationCodeFrom(ok), 'abc');
      expect(
        () => request.authorizationCodeFrom(
          Uri.parse('com.example.app:/callback?code=abc&state=forged'),
        ),
        throwsA(
          isA<OidcCallbackException>().having(
            (e) => e.code,
            'code',
            'state_mismatch',
          ),
        ),
      );
      expect(
        () => request.authorizationCodeFrom(
          Uri.parse('com.example.app:/callback?error=access_denied'),
        ),
        throwsA(
          isA<OidcCallbackException>().having(
            (e) => e.code,
            'code',
            'access_denied',
          ),
        ),
      );
    });
  });

  group('AuthCoordinator', () {
    test('forceRefresh refreshes an unexpired token', () async {
      final store = SecureTokenStore(InMemorySecureStorage());
      await store.save(tokens('current', DateTime.utc(2030)));
      final oidc = FakeOidcClient(
        authorized: tokens('a', DateTime.utc(2030)),
        refreshed: tokens('refreshed', DateTime.utc(2030)),
      );
      final auth = AuthCoordinator(
        oidc: oidc,
        tokenStore: store,
        clock: FakeClock(DateTime.utc(2026)),
      );
      final provider = AuthCoordinatorTokenProvider(auth);
      expect(await provider.accessToken(), 'current');
      expect(await provider.refreshAccessToken(), 'refreshed');
      expect(oidc.refreshCalls, 1);
      expect((await store.read())?.accessToken, 'refreshed');
      await auth.dispose();
    });

    test('transient refresh failures keep the session', () async {
      final store = SecureTokenStore(InMemorySecureStorage());
      await store.save(tokens('expired', DateTime.utc(2025)));
      final auth = AuthCoordinator(
        oidc: _FailingOidc(ApiFailure.offline(correlationId: 'c')),
        tokenStore: store,
        clock: FakeClock(DateTime.utc(2026)),
      );
      final snapshot = await auth.restore();
      expect(snapshot.status, AuthStatus.authenticated);
      expect(snapshot.errorCode, 'refresh_unavailable');
      expect(await store.read(), isNotNull);
      await auth.dispose();
    });

    test('rejected refresh clears tokens and expires the session', () async {
      final store = SecureTokenStore(InMemorySecureStorage());
      await store.save(tokens('expired', DateTime.utc(2025)));
      final auth = AuthCoordinator(
        oidc: _FailingOidc(
          const ApiFailure(
            kind: ApiFailureKind.unauthorized,
            code: 'invalid_grant',
            message: 'Expired.',
            correlationId: 'c',
            retryable: false,
          ),
        ),
        tokenStore: store,
        clock: FakeClock(DateTime.utc(2026)),
      );
      final snapshot = await auth.restore();
      expect(snapshot.status, AuthStatus.expired);
      expect(await store.read(), isNull);
      await auth.dispose();
    });

    test('does not re-emit identical snapshots', () async {
      final store = SecureTokenStore(InMemorySecureStorage());
      await store.save(tokens('current', DateTime.utc(2030)));
      final auth = AuthCoordinator(
        oidc: FakeOidcClient(
          authorized: tokens('a', DateTime.utc(2030)),
          refreshed: tokens('b', DateTime.utc(2030)),
        ),
        tokenStore: store,
        clock: FakeClock(DateTime.utc(2026)),
      );
      final emitted = <AuthStatus>[];
      auth.snapshots.listen((s) => emitted.add(s.status));
      await auth.validTokens();
      await auth.validTokens();
      await auth.validTokens();
      expect(emitted, <AuthStatus>[AuthStatus.authenticated]);
      await auth.dispose();
    });
  });
}

final class _FailingOidc implements OidcClient {
  _FailingOidc(this.error);

  final Object error;

  @override
  Future<AuthTokens> authorize(OidcAuthorizationRequest request) =>
      throw UnimplementedError();

  @override
  Future<AuthTokens> refresh(String refreshToken) async => throw error;

  @override
  Future<void> revoke(String refreshToken) async {}
}
