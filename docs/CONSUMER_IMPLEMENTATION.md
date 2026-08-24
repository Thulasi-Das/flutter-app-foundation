# Consumer implementation guide

This guide shows how a Flutter product should integrate the foundation. The
foundation supplies contracts, coordinators, UI primitives, and deterministic
reference adapters. The consuming application owns product entities, generated
API models, state management, and platform/vendor adapters.

## 1. Add the dependency

For local development, reference the checkout from the product's
`pubspec.yaml`:

```yaml
dependencies:
  flutter_app_foundation:
    path: ../flutter-app-foundation
```

Then run:

```bash
flutter pub get
```

The package currently has `publish_to: none`. For a shared prerelease, use a
reviewed immutable Git tag. Pin an exact compatible version after a registry
release.

## 2. Select a composition

| Application need                                 | Recommended library                      |
| ------------------------------------------------ | ---------------------------------------- |
| Connected application shell                      | `foundation_preset_minimal.dart`         |
| Authentication, notifications, and observability | `foundation_preset_connected.dart`       |
| Local data, backup, and synchronization          | `foundation_preset_offline.dart`         |
| Specialized application                          | individual `foundation_*.dart` libraries |

Import one preset at the application composition root:

```dart
import 'package:flutter_app_foundation/foundation_preset_offline.dart';
```

A preset only re-exports public APIs. It does not initialize plugins, request
permissions, select state management, or configure a vendor.

## 3. Build a product composition root

Create a file such as `lib/app/product_dependencies.dart`. Construct adapters
once and inject repositories or view models into feature code.

```dart
final class ProductDependencies {
  ProductDependencies({
    required this.database,
    required this.auth,
    required this.network,
    required this.sync,
  });

  final ProductSqliteDatabase database;
  final AuthCoordinator auth;
  final NetworkClient network;
  final SyncCoordinator sync;

  static Future<ProductDependencies> create() async {
    final database = ProductSqliteDatabase();
    final secureStorage = ProductSecureStorageAdapter();
    final auth = AuthCoordinator(
      oidc: ProductOidcClient(),
      tokenStore: SecureTokenStore(secureStorage),
      clock: const SystemClock(),
    );

    final httpClient = ProductHttpClient();
    final network = NetworkClient(
      transport: ProductHttpTransport(httpClient),
      ids: ProductUuidGenerator(),
      accessTokens: ProductAccessTokenProvider(auth),
      appVersion: productBuildVersion,
    );

    final sync = SyncCoordinator(
      remote: ProductRemoteSyncAdapter(network),
      store: ProductSqliteSyncStore(database),
      clock: const SystemClock(),
    );

    return ProductDependencies(
      database: database,
      auth: auth,
      network: network,
      sync: sync,
    );
  }
}
```

Names beginning with `Product` are adapters implemented by the consuming
application. Use maintained packages for UUIDs, OIDC, HTTP, secure storage, and
SQLite rather than writing security or persistence primitives from scratch.

## 4. Configure and bootstrap the app

Validate flavor configuration before rendering product features:

```dart
final configuration = AppConfiguration(
  environment: AppEnvironment.production,
  apiBaseUri: Uri.parse('https://api.example.com'),
  release: '1.4.0',
  buildNumber: '10400',
  appId: 'com.example.product',
);

final dependencies = await ProductDependencies.create();

final bootstrap = BootstrapCoordinator(<StartupStep>[
  StartupStep(id: 'database', run: () async {
    await dependencies.database.open();
  }),
  StartupStep(id: 'session', run: () async {
    await dependencies.auth.restore();
  }),
  StartupStep(
    id: 'telemetry',
    required: false,
    run: () async {
      await productTelemetry.start();
    },
  ),
]);

await bootstrap.start();
```

Required-step failure should render a recoverable bootstrap state. Optional
telemetry or provider failure must not block access to locally safe product
data.

## 5. Implement authentication adapters

`ProductOidcClient` implements `OidcClient` using system-browser Authorization
Code with PKCE. It must validate state, nonce, issuer, audience, redirect URI,
token signature, expiry, and key rotation.

Bridge valid access tokens into the network layer:

```dart
final class ProductAccessTokenProvider implements AccessTokenProvider {
  ProductAccessTokenProvider(this.auth);

  final AuthCoordinator auth;

  @override
  Future<String?> accessToken() async =>
      (await auth.validTokens())?.accessToken;
}
```

Implement `SecureStorage` with Keychain, Keystore, or the appropriate desktop
credential vault. `InMemorySecureStorage` and `FakeOidcClient` are test/reference
adapters and must not hold production credentials.

## 6. Implement the network adapter

`ProductHttpTransport` maps the selected HTTP package to `NetworkTransport`:

```dart
final class ProductHttpTransport implements NetworkTransport {
  ProductHttpTransport(this.client);

  final ProductHttpClient client;

  @override
  Future<NetworkResponse> send(NetworkRequest request) async {
    final response = await client.send(
      method: request.method.name.toUpperCase(),
      uri: request.uri,
      headers: request.headers,
      body: request.body,
    );
    return NetworkResponse(
      statusCode: response.statusCode,
      headers: response.headers,
      body: response.decodedBody,
    );
  }
}
```

The concrete adapter must preserve cancellation and timeout behavior supported
by the selected client. `NetworkClient` adds correlation, idempotency, access
token, locale, app-version, and bounded retry behavior.

Use a stable idempotency key for retryable writes:

```dart
await dependencies.network.send(NetworkRequest(
  method: HttpMethod.post,
  uri: configuration.apiBaseUri.resolve('/api/v1/projects'),
  idempotencyKey: mutationId,
  body: projectCommand.toJson(),
));
```

## 7. Put product behavior behind repositories

Views and widgets should consume product repositories or view models, not raw
network responses, database rows, or plugin objects:

```dart
final class ProjectsRepository {
  ProjectsRepository(this.network);

  final NetworkClient network;

  Future<List<ProjectSummary>> list() async {
    final response = await network.send(NetworkRequest(
      method: HttpMethod.get,
      uri: productApiBase.resolve('/api/v1/projects'),
    ));
    return ProjectSummary.listFromJson(response.body);
  }
}
```

Generated API models and product records remain in the consuming application.

## 8. Implement offline persistence and sync

The production SQLite adapter must implement two atomic boundaries:

1. a product record update and its outbox mutation commit together;
2. a pulled change page and its cursor commit together.

Construct synchronization with product adapters:

```dart
final sync = SyncCoordinator(
  remote: ProductRemoteSyncAdapter(network),
  store: ProductSqliteSyncStore(database),
  clock: const SystemClock(),
  maxBatchCount: 100,
  maxBatchBytes: 512 * 1024,
);

final result = await sync.synchronize(activeWorkspaceId);
```

The remote adapter must preserve workspace scope, mutation IDs, base versions,
conflict/rejection results, bounded pull pages, and normalized errors. Keep
conflicts visible as action-required product state; do not silently overwrite
them.

Use `InMemorySyncStore` only for reference behavior and contract tests.

## 9. Mount the UI surface

Use the foundation theme and bootstrap gate at the app boundary while retaining
product ownership of screens and navigation:

```dart
MaterialApp(
  theme: FoundationTheme.light(),
  darkTheme: FoundationTheme.dark(),
  home: BootstrapGate(
    coordinator: bootstrap,
    child: ProductHome(dependencies: dependencies),
  ),
);
```

`AdaptiveAppShell` provides a baseline phone/rail layout. Desktop products
still need explicit window, keyboard, focus, updater, signing, file, vault, and
multi-instance design.

## 10. Handle lifecycle and cleanup

- Restore authentication during bootstrap.
- Trigger opportunistic sync after successful connectivity, resume, or a user
  action; do not treat a connectivity signal as proof of reachability.
- Subscribe to coordinator streams in an application-level owner.
- Dispose `AuthCoordinator`, `SyncCoordinator`, and `BootstrapCoordinator` when
  the dependency owner is destroyed.
- Close database and transport resources owned by product adapters.
- Keep notification payloads opaque and lock-screen safe.

## 11. Test every production adapter

Run contract tests against the deterministic reference behavior and cover:

- OIDC redirect, state/nonce, refresh rotation, expiry, revocation, and secure
  storage behavior;
- HTTP timeout, cancellation, retry, idempotency, and normalized failures;
- migration from every released SQLite schema;
- interrupted writes, record/outbox atomicity, and cursor/page atomicity;
- duplicate mutation delivery, conflicts, permanent rejection, and restart;
- backup checksum, encryption adapter, staging, migration, and atomic restore;
- notification, deep-link, lifecycle, background, and poor-network behavior;
- accessibility semantics, focus, keyboard, large text, contrast, and reduced
  motion.

Validate on real target devices before release. Web compilation is not a
substitute for Android, iOS, macOS, or Windows adapter validation.

## 12. Production checklist

- Pin an immutable foundation version.
- Keep tokens only in platform secure storage.
- Keep provider and database credentials on the authorized backend.
- Use HTTPS and never add certificate-validation bypasses.
- Classify every persisted field and notification payload.
- Protect local databases and backups according to the product threat model.
- Add dependency, secret, license, SAST, signing, and provenance checks.
- Stage product releases and retain a safe migration/rollback path.

See the [integration guide](INTEGRATION.md), [architecture](ARCHITECTURE.md),
[security contract](SECURITY.md), and [release policy](RELEASING.md) for the
underlying contracts.
