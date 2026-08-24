# Flutter App Foundation

Use the [storage provider guide](docs/STORAGE_PROVIDERS.md) to add local file,
local SQLite, Google Sheets, Airtable, backend-brokered database, or future
managed workspace storage behind the same contract used by Django.
Use the [telemetry guide](docs/TELEMETRY.md) for purpose-specific consent,
strict event schemas, safe error diagnostics, regional policy presets, and
optional commercial insights.

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
- a Django-compatible privacy-first workspace store registry, local file
  adapter, and pluggable SQLite driver adapter;
- offline outbox/push/pull contracts and a single-flight sync coordinator;
- staged backup/restore contracts;
- allowlist-based structured logging and telemetry ports;
- default-deny, consent-governed product telemetry with withdrawal purge and
  Django-compatible regional policy presets;
- ports for connectivity, lifecycle, notifications, deep links, flags,
  localization, accessibility, and mobile security controls;
- test clocks, IDs, fakes, example app, tests, and CI.

The foundation deliberately does **not** contain product entities, vendor
credentials, generated API models, or platform plugin choices.

## Capability boundaries

New applications can import only the capabilities they use:

```dart
import 'package:flutter_app_foundation/foundation_app.dart';
import 'package:flutter_app_foundation/foundation_auth.dart';
import 'package:flutter_app_foundation/foundation_contracts.dart';
import 'package:flutter_app_foundation/foundation_network.dart';
```

Or start from `foundation_preset_minimal.dart`,
`foundation_preset_connected.dart`, or `foundation_preset_offline.dart`.
Presets are ordinary Dart re-export libraries, so there is no service locator
or hidden runtime registration.

The original aggregate imports remain backward compatible:

```dart
import 'package:flutter_app_foundation/flutter_app_foundation.dart';
import 'package:flutter_app_foundation/flutter_app_foundation_ui.dart';
```

The first library is vendor-neutral application infrastructure. The second is
the Flutter widget/theme surface. Consumers provide adapters for Keychain or
Keystore, SQLite/Drift, HTTP/Dio, OIDC, APNs/FCM, analytics, and crash vendors.

## Use from another Flutter application

The package currently has `publish_to: none`, so consume it through a local path
or an immutable Git reference. For local development, add this to the consuming
application's `pubspec.yaml`:

```yaml
dependencies:
  flutter_app_foundation:
    path: ../flutter-app-foundation
```

Choose the smallest suitable composition:

| Preset                             | Intended application                                           |
| ---------------------------------- | -------------------------------------------------------------- |
| `foundation_preset_minimal.dart`   | connected application shell                                    |
| `foundation_preset_connected.dart` | authenticated app with observability and notifications         |
| `foundation_preset_offline.dart`   | offline-first app with local data, backup, and synchronization |

Then fetch dependencies and choose a preset:

```bash
flutter pub get
```

```dart
import 'package:flutter_app_foundation/foundation_preset_offline.dart';
```

Applications with a narrower composition can import capabilities directly:

```dart
import 'package:flutter_app_foundation/foundation_contracts.dart';
import 'package:flutter_app_foundation/foundation_auth.dart';
import 'package:flutter_app_foundation/foundation_data.dart';
import 'package:flutter_app_foundation/foundation_storage.dart';
import 'package:flutter_app_foundation/foundation_sync.dart';
import 'package:flutter_app_foundation/foundation_telemetry.dart';
```

Create the concrete dependency graph at application startup:

```dart
final coordinator = SyncCoordinator(
  remote: ProductRemoteSyncAdapter(apiClient),
  store: ProductDriftSyncStore(database),
  clock: const SystemClock(),
);
```

The product supplies and contract-tests its OIDC, secure-storage, SQLite,
network, notification, telemetry, and crash-reporting adapters. Product
entities, generated API models, authorization decisions, vendor credentials,
and platform signing configuration remain outside this package. This is an
embedded package, not a hosted API, and therefore has no foundation API key.

For reuse without a local checkout, reference a reviewed immutable Git tag:

```yaml
dependencies:
  flutter_app_foundation:
    git:
      url: https://github.com/Thulasi-Das/flutter-app-foundation.git
      ref: v0.1.0
```

Remove `publish_to: none`, complete the release gates, and publish an immutable
version before replacing the path or Git dependency with a registry version.

For composition-root wiring, authentication, network and sync adapters,
repository patterns, lifecycle, and device validation, read the
[consumer implementation guide](docs/CONSUMER_IMPLEMENTATION.md).

For permissioned analytics and exception reporting, read the
[telemetry implementation guide](docs/TELEMETRY.md).

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
