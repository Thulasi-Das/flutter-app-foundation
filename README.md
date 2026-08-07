# Flutter App Foundation

A product-neutral Flutter package for mobile-first and future desktop products.
It supplies stable ports, reference behavior, accessible UI primitives, and test
fakes while keeping product domain models and vendor SDKs in consuming apps.

## What v0.1 provides

- ordered, observable application bootstrap and validated flavor configuration;
- light, dark, system, and high-contrast-ready semantic themes;
- accessible fields, app states, banners, and adaptive navigation shell;
- OIDC/PKCE and secure token-storage contracts with serialized refresh logic;
- typed transport failures, correlation/idempotency headers, cancellation, and
  bounded retry rules;
- migration/database contracts and an atomic in-memory reference database;
- offline outbox/push/pull contracts and a single-flight sync coordinator;
- staged backup/restore contracts;
- allowlist-based structured logging and telemetry ports;
- ports for connectivity, lifecycle, notifications, deep links, flags,
  localization, accessibility, and mobile security controls;
- test clocks, IDs, fakes, example app, tests, and CI.

The foundation deliberately does **not** contain product entities, vendor
credentials, generated API models, or platform plugin choices.

## Package boundaries

```dart
import 'package:flutter_app_foundation/flutter_app_foundation.dart';
import 'package:flutter_app_foundation/flutter_app_foundation_ui.dart';
```

The first library is vendor-neutral application infrastructure. The second is
the Flutter widget/theme surface. Consumers provide adapters for Keychain or
Keystore, SQLite/Drift, HTTP/Dio, OIDC, APNs/FCM, analytics, and crash vendors.

## Quick start

```dart
final configuration = AppConfiguration(
  environment: AppEnvironment.development,
  apiBaseUri: Uri.parse('https://api.example.test'),
  release: 'local',
  buildNumber: '1',
  appId: 'example.app',
);

final bootstrap = BootstrapCoordinator(<StartupStep>[
  StartupStep(id: 'database', run: () async {}),
  StartupStep(id: 'session', run: () async {}),
]);

await bootstrap.start();
```

See [architecture](docs/ARCHITECTURE.md), [integration guide](docs/INTEGRATION.md),
[security contract](docs/SECURITY.md), and the [example](example/lib/main.dart).

## Validation

```bash
flutter pub get
dart format --output=none --set-exit-if-changed .
flutter analyze
flutter test --coverage
flutter build web --target example/lib/main.dart
```

Version `0.1.x` is an integration-preview API. Product repositories should pin
an exact compatible version until `1.0.0`.
