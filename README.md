# Flutter App Foundation

A product-neutral foundation for Flutter apps on mobile, web, and desktop.
Import it, write `main()`, and you have production error handling, theming,
routing, startup gating, a typed HTTP client, auth token handling, state
management, accessible widgets, and test fakes. You write the features.

Product domain models and vendor SDKs stay in your app. The foundation defines
small ports (interfaces) for them and ships working adapters wherever a
plugin-free one is possible.

## Quick start

**1. Add the dependency** (pin an immutable tag; see [Releasing](docs/RELEASING.md)):

```yaml
dependencies:
  flutter_app_foundation:
    git:
      url: https://github.com/Thulasi-Das/flutter-app-foundation.git
      ref: v0.2.0
```

**2. Write `main.dart`:**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_app_foundation/foundation_preset_minimal.dart';

Future<void> main() => runFoundationApp(() async {
  final api = NetworkClient(
    transport: HttpNetworkTransport(),
    ids: UuidV4Generator(),
    baseUri: Uri.parse('https://api.example.com/v1'),
  );
  final theme = ThemeController(store: InMemoryKeyValueStore());

  return FoundationApp(
    title: 'My App',
    seedColor: Colors.teal,
    themeController: theme,
    bootstrap: BootstrapCoordinator([
      StartupStep(id: 'theme', run: theme.load, required: false),
    ]),
    services: [ServiceBinding<NetworkClient>(api)],
    routeTable: FoundationRouteTable(routes: [
      FoundationRoute(
        destination: const AppDestination(name: 'home', path: '/'),
        builder: (context, _) => const ProjectsPage(),
      ),
      FoundationRoute(
        destination: const AppDestination(name: 'project', path: '/projects/:id'),
        builder: (context, match) => ProjectPage(id: match.pathParameters['id']!),
      ),
    ]),
  );
});
```

**3. Write a screen.** Loading, empty, offline, and error states are handled:

```dart
class ProjectsPage extends StatefulWidget {
  const ProjectsPage({super.key});
  @override
  State<ProjectsPage> createState() => _ProjectsPageState();
}

class _ProjectsPageState extends State<ProjectsPage> {
  late final projects = AsyncController<List<Object?>>(
    load: () => context.service<NetworkClient>().getJson('projects'),
  )..refresh();

  @override
  void dispose() {
    projects.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Projects')),
    body: AsyncValueBuilder<List<Object?>>(
      controller: projects,
      isEmpty: (items) => items.isEmpty,
      builder: (context, items) => ListView(
        children: [for (final item in items) ListTile(title: Text('$item'))],
      ),
    ),
  );
}
```

The [example app](example/lib) is a complete, tested starter: composition
root, repository interface with HTTP and demo implementations, list/detail
routes, optimistic updates, forms with validation, and persisted theme
settings. Copy it to start a new product.

## What you get

| Area | Import | Ready-to-use pieces |
| --- | --- | --- |
| App runtime | `flutter_app_foundation_ui.dart` | `runFoundationApp` (framework, platform, and startup error capture), `FoundationApp` (light/dark/high-contrast themes, bootstrap gate, forced-update gate, localizable strings, service scopes), `ThemeController` |
| State and DI | `foundation_state.dart` | `AsyncValue`, `AsyncController` (latest-wins, dispose-safe, stale-while-revalidate), `AsyncValueBuilder`, `ServiceScope`/`MultiServiceScope` |
| Routing | `flutter_app_foundation_ui.dart`, `foundation_app.dart` | `FoundationRouteTable` (path and query parameters, auth redirect, deep-link initial stack, not-found page), `NavigatorNavigationDriver`, `GuardedNavigationDriver`, `AuthenticationRouteGuard`; or pass any `routerConfig` (e.g. go_router) |
| Networking | `foundation_network.dart` | `HttpNetworkTransport` (all platforms, abortable timeouts and cancellation), `NetworkClient` (base URI, JSON helpers, correlation and idempotency headers, bounded retries with `Retry-After`, automatic token refresh on `401`), typed `ApiFailure` |
| Auth | `foundation_auth.dart` | `AuthCoordinator` (single-flight refresh, offline-tolerant), `AuthCoordinatorTokenProvider`, `SecureTokenStore`, PKCE S256 request builder with state validation |
| UI kit | `flutter_app_foundation_ui.dart` | Semantic themes and tokens, adaptive navigation shell, accessible fields, `FoundationValidators`, `FoundationAsyncButton`, state views, banners, snack bars, confirmation dialogs |
| Data | `foundation_data.dart`, `foundation_local_file_storage.dart` | `KeyValueStore` (in-memory and atomic file adapters), local database and migration contracts, workspace storage registry with file and SQLite adapters, backup/restore with SHA-256 |
| Offline sync | `foundation_sync.dart` | Outbox, push/pull ports, single-flight `SyncCoordinator` |
| Observability | `foundation_observability.dart`, `foundation_telemetry.dart` | Allowlist-redacting `StructuredLogger`, debug and fan-out sinks, `CrashReporter` port with logging and fan-out reporters, consent-gated telemetry |
| Platform | `foundation_app.dart`, `flutter_app_foundation_ui.dart` | Lifecycle and accessibility adapters, connectivity, deep-link validation, feature flags, notifications, security ports |
| Contracts | `foundation_contracts.dart` | `Result`, `UuidV4Generator`, `AppVersion`, clocks |
| Testing | `foundation_testing.dart` | Fake clock, IDs, scripted transport, fake OIDC and sync, widget harness |

### Presets

Presets are plain re-export libraries; there is no hidden registration.

| Preset | For |
| --- | --- |
| `foundation_preset_minimal.dart` | A connected app: runtime, UI, state, network, preferences, observability |
| `foundation_preset_connected.dart` | Adds auth, notifications, and consent telemetry |
| `foundation_preset_offline.dart` | Adds local data, workspace storage, backup, and sync |

You can also import individual capability libraries instead of a preset.
`flutter_app_foundation.dart` (pure Dart core) and
`flutter_app_foundation_ui.dart` (Flutter surface) remain as aggregate
imports.

## Before you ship

The foundation deliberately avoids platform plugins. Before release, supply
these adapters in your app; each is a few lines, shown in
[Adapter recipes](docs/RECIPES.md):

- `SecureStorage` over Keychain/Keystore (e.g. `flutter_secure_storage`).
  `InMemorySecureStorage` is for tests only.
- `OidcClient` for your identity provider (e.g. `flutter_appauth`).
- `KeyValueStore` over `shared_preferences`, or `FileKeyValueStore` with a
  `path_provider` directory.
- `CrashReporter` for your crash vendor, honouring reliability consent.
- A SQLite/Drift `LocalDatabase` and `SyncStore` if you work offline.

Then follow the [consumer implementation guide](docs/CONSUMER_IMPLEMENTATION.md)
and the [product release gate](docs/RELEASING.md).

## Documentation

- [Adapter recipes](docs/RECIPES.md): secure storage, preferences, OIDC,
  crash reporting, go_router, localization
- [Architecture](docs/ARCHITECTURE.md) and [integration guide](docs/INTEGRATION.md)
- [Consumer implementation guide](docs/CONSUMER_IMPLEMENTATION.md)
- [Security contract](docs/SECURITY.md)
- [Storage providers](docs/STORAGE_PROVIDERS.md) and [telemetry](docs/TELEMETRY.md)
- [Testing and release policy](docs/RELEASING.md)

## Requirements

Flutter 3.35 or later (Dart 3.9 or later). CI tests the minimum version and
current stable.

## Development

```bash
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze --fatal-infos
flutter test --coverage
dart run --enable-asserts tool/self_check.dart
(cd example && flutter test)
```

Versions `0.x` are pre-1.0: pin an exact tag, and read the
[changelog](CHANGELOG.md) before upgrading.
