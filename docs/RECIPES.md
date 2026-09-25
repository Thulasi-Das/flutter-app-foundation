# Adapter recipes

The foundation defines ports and keeps platform plugins out of the package.
These adapters connect common plugins in a few lines. Add the plugin to your
app's `pubspec.yaml`, copy the adapter into your app, and contract-test it on
real devices.

Plugin APIs change between major versions; check each plugin's own
documentation for the version you install.

## Secure storage (`flutter_secure_storage`)

```dart
import 'package:flutter_app_foundation/foundation_auth.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

final class PluginSecureStorage implements SecureStorage {
  const PluginSecureStorage([this._storage = const FlutterSecureStorage()]);

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) =>
      _storage.write(key: key, value: value);

  @override
  Future<void> delete(String key) => _storage.delete(key: key);

  @override
  Future<void> deleteAll() => _storage.deleteAll();
}

// Composition root:
final tokenStore = SecureTokenStore(const PluginSecureStorage());
```

## Preferences (`shared_preferences`)

```dart
import 'package:flutter_app_foundation/foundation_preferences.dart';
import 'package:shared_preferences/shared_preferences.dart';

final class SharedPreferencesStore implements KeyValueStore {
  SharedPreferencesStore([SharedPreferencesAsync? preferences])
    : _preferences = preferences ?? SharedPreferencesAsync();

  final SharedPreferencesAsync _preferences;

  @override
  Future<String?> read(String key) => _preferences.getString(key);

  @override
  Future<void> write(String key, String value) =>
      _preferences.setString(key, value);

  @override
  Future<void> delete(String key) => _preferences.remove(key);

  @override
  Future<Map<String, String>> readAll() async => {
    for (final entry in (await _preferences.getAll()).entries)
      if (entry.value is String) entry.key: entry.value! as String,
  };
}
```

Without a plugin, on mobile and desktop, `FileKeyValueStore` from
`foundation_local_file_storage.dart` persists atomically to one JSON file:

```dart
final directory = await getApplicationSupportDirectory(); // path_provider
final preferences = FileKeyValueStore(File('${directory.path}/prefs.json'));
```

## Sign-in (`flutter_appauth`)

`flutter_appauth` performs the system-browser Authorization Code + PKCE flow,
so the adapter maps its responses to `AuthTokens`:

```dart
import 'package:flutter_app_foundation/foundation_auth.dart';
import 'package:flutter_appauth/flutter_appauth.dart';

final class AppAuthOidcClient implements OidcClient {
  AppAuthOidcClient({
    required this.issuer,
    required this.clientId,
    required this.redirectUri,
    required this.revocation,
  });

  final String issuer;
  final String clientId;
  final String redirectUri;
  final Future<void> Function(String refreshToken) revocation;
  final FlutterAppAuth _appAuth = const FlutterAppAuth();

  @override
  Future<AuthTokens> authorize(OidcAuthorizationRequest request) async {
    final response = await _appAuth.authorizeAndExchangeCode(
      AuthorizationTokenRequest(
        request.clientId,
        request.redirectUri.toString(),
        issuer: issuer,
        scopes: request.scopes,
      ),
    );
    return _tokens(response);
  }

  @override
  Future<AuthTokens> refresh(String refreshToken) async => _tokens(
    await _appAuth.token(
      TokenRequest(
        clientId,
        redirectUri,
        issuer: issuer,
        refreshToken: refreshToken,
      ),
    ),
  );

  @override
  Future<void> revoke(String refreshToken) => revocation(refreshToken);

  AuthTokens _tokens(TokenResponse response) => AuthTokens(
    accessToken: response.accessToken!,
    refreshToken: response.refreshToken!,
    accessTokenExpiresAt: response.accessTokenExpirationDateTime!.toUtc(),
    idToken: response.idToken,
  );
}
```

Throw an
`ApiFailure` with `retryable: true` from `refresh` for network errors, so
`AuthCoordinator` keeps the session instead of signing the user out.

Wire auth into every API call:

```dart
final auth = AuthCoordinator(
  oidc: AppAuthOidcClient(
    issuer: issuer,
    clientId: clientId,
    redirectUri: redirectUri,
    revocation: revokeViaApi,
  ),
  tokenStore: SecureTokenStore(const PluginSecureStorage()),
  clock: const SystemClock(),
);
final api = NetworkClient(
  transport: HttpNetworkTransport(),
  ids: UuidV4Generator(),
  baseUri: configuration.apiBaseUri,
  accessTokens: AuthCoordinatorTokenProvider(auth), // refreshes once on 401
);
```

If you implement the redirect yourself, `OidcAuthorizationRequest.withPkce`
generates `state`, `nonce`, and the S256 challenge; open
`request.authorizationUri` in the system browser and pass the callback URI to
`request.authorizationCodeFrom(callback)`, which rejects mismatched `state`.

## Crash reporting (Sentry, Crashlytics, ...)

```dart
final class SentryCrashReporter implements CrashReporter {
  const SentryCrashReporter(this.consent);

  final bool Function() consent; // reliability consent from ConsentGatedTelemetry

  @override
  Future<void> recordError(
    Object error,
    StackTrace? stackTrace, {
    required bool fatal,
    String? source,
  }) async {
    if (!consent()) return;
    await Sentry.captureException(error, stackTrace: stackTrace);
  }
}

Future<void> main() => runFoundationApp(
  buildApp,
  crashReporter: FanOutCrashReporter([
    LoggingCrashReporter(logger),
    SentryCrashReporter(consent),
  ]),
);
```

Initialize vendor SDKs inside the `runFoundationApp` builder or a bootstrap
step, and configure them to scrub personal data (see [Telemetry](TELEMETRY.md)).

## Routing with go_router

`FoundationApp` accepts any `RouterConfig`. The bootstrap gate, themes,
strings, and services still apply:

```dart
FoundationApp(
  title: 'My App',
  routerConfig: GoRouter(routes: [...]),
  services: [...],
);
```

Use `FoundationRouteTable` when you want Navigator-based routing without an
additional dependency.

## Localization

`FoundationStrings` holds every string the foundation renders. Build it from
your app's generated localizations:

```dart
FoundationApp(
  title: 'My App',
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  stringsBuilder: (context) {
    final l10n = AppLocalizations.of(context);
    return FoundationStrings(
      retry: l10n.retry,
      offlineTitle: l10n.offlineTitle,
      // ...
    );
  },
);
```

`stringsBuilder` runs below `Localizations`, so the translated strings also
reach the startup, update, and not-found screens.

Validators take a `message` argument for the same reason.

## Forced updates

```dart
final configuration = AppConfiguration.fromCompileTime()
    .mergeApprovedRemote(await remoteConfiguration.load());

FoundationApp(
  title: 'My App',
  updateRequired: configuration.requiresUpdate,
  onUpdateRequested: openStoreListing,
  ...
);
```
