import 'package:flutter_app_foundation/flutter_app_foundation.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('secure token store round-trips and clears only auth keys', () async {
    final secure = InMemorySecureStorage();
    await secure.write('unrelated', 'keep');
    final store = SecureTokenStore(secure);
    final tokens = AuthTokens(
      accessToken: 'access',
      refreshToken: 'refresh',
      accessTokenExpiresAt: DateTime.utc(2030),
    );

    await store.save(tokens);
    expect((await store.read())?.accessToken, 'access');
    await store.clear();
    expect(await store.read(), isNull);
    expect(await secure.read('unrelated'), 'keep');
  });

  test('concurrent token requests serialize refresh', () async {
    final clock = FakeClock(DateTime.utc(2026));
    final storage = InMemorySecureStorage();
    final store = SecureTokenStore(storage);
    await store.save(
      AuthTokens(
        accessToken: 'expired',
        refreshToken: 'refresh-1',
        accessTokenExpiresAt: DateTime.utc(2025),
      ),
    );
    final oidc = FakeOidcClient(
      authorized: AuthTokens(
        accessToken: 'authorized',
        refreshToken: 'refresh-a',
        accessTokenExpiresAt: DateTime.utc(2027),
      ),
      refreshed: AuthTokens(
        accessToken: 'fresh',
        refreshToken: 'refresh-2',
        accessTokenExpiresAt: DateTime.utc(2027),
      ),
    );
    final coordinator = AuthCoordinator(
      oidc: oidc,
      tokenStore: store,
      clock: clock,
    );

    final results = await Future.wait(<Future<AuthTokens?>>[
      coordinator.validTokens(),
      coordinator.validTokens(),
      coordinator.validTokens(),
    ]);

    expect(oidc.refreshCalls, 1);
    expect(results.map((item) => item?.accessToken), everyElement('fresh'));
    expect(coordinator.snapshot.status, AuthStatus.authenticated);
    await coordinator.dispose();
  });
}
