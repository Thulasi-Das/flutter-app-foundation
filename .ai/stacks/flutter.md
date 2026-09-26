# Stack profile: Flutter / Dart

Applies to Flutter code, both `flutter-app-foundation` itself and apps built on it.
`PROJECT.md` overrides any convention here where it is more specific.

## Layers

```text
widgets/features -> controller / view model -> product repository
                                                 |-- local database adapter (SQLite)
                                                 |-- outbox / sync coordinator
                                                 `-- generated remote API adapter
```

| Layer | Does | Never does |
|---|---|---|
| Widgets | render state, capture intent, call controller methods | import `sqflite`, HTTP, secure storage, or provider SDKs; read raw responses or rows |
| Controller / view model | orchestrate commands, expose `AsyncValue` state | talk to a platform plugin directly |
| Repository | own the domain commands; commit the local change and outbox mutation in one transaction | build widgets |
| Adapters | implement foundation ports (`NetworkTransport`, `LocalDatabase`, `SecureStorage`, `Telemetry`, ...) | contain domain rules |

## Use the foundation's paved paths (apps)

- Import only barrel libraries (`package:flutter_app_foundation/foundation_*.dart`, a preset, or
  `flutter_app_foundation_ui.dart`). Never import `lib/src/**`. Never copy or patch foundation
  source. If the foundation lacks something, add it upstream or write a local adapter.
- Pin the foundation to an immutable tag or commit. `pubspec_overrides.yaml` for local development
  is never committed.
- **Dependency injection:** explicit constructors plus typed `ServiceScope`s created at the
  composition root. No global service locator, static token cache, or global mutable database.
- **State:** `AsyncController` / `AsyncValue` / `AsyncValueBuilder`. Loading, empty, offline, and
  error states are explicit.
- **Startup:** `runFoundationApp` with a `BootstrapCoordinator`. Mark optional steps
  `required: false`.
- **Network:** `NetworkClient` over a `NetworkTransport` with the shared headers and error envelope.
  A successful request is the only proof of connectivity; connectivity APIs are hints.

## Security and storage

- Secrets and tokens live only in `SecureStorage` (Keychain/Keystore). Never in SQLite,
  preferences, files, logs, or backups.
- Backups are checksummed and, when they contain personal data, encrypted with a reviewed library.
  No home-grown cryptography.
- Platform hardening (Android network security config, iOS ATS, backup exclusions) is checked in.
  Do not relax it to make something work.
- Push notification payloads are opaque. Fetch content after open.

## Data and migrations

- Every schema change bumps the SQLite version with a forward migration and a test that opens a
  database at the previous version.
- Never delete or re-key user data to avoid writing a migration. Export and import stay compatible.

## Style and analysis

- `dart format` is enforced. `flutter analyze` runs with the repository's options (the foundation
  uses `--fatal-infos`). Do not add `// ignore:` without a reason.
- Strings visible to users come from ARB localization. No literal user-facing strings in widgets.
- Accessibility: semantics labels, minimum touch targets, text scaling, and contrast in both themes.

## Tests

- `flutter test` for units and widgets, using the foundation's fakes from
  `foundation_testing.dart`. `integration_test/` covers journeys.
- Required coverage for a change: repository command plus outbox entry in one transaction, the
  migration from the previous version, controller state transitions, and widget behaviour for new
  states.
