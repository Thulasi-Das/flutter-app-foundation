# Changelog

## 0.2.0

Apps can now be built on the foundation directly, without first writing
infrastructure adapters.

### Added

- `runFoundationApp`: routes Flutter, platform, and startup errors to a
  `CrashReporter`, uses a neutral error widget in release builds, and shows a
  failure screen when the root builder throws.
- `FoundationApp`: `MaterialApp`/`MaterialApp.router` root with light, dark,
  and high-contrast themes, `ThemeController`, bootstrap gate, forced-update
  gate, localizable `FoundationStrings` (`strings`/`stringsBuilder`), and
  service scopes.
- State and DI (`foundation_state.dart`): `AsyncValue`, `AsyncController`,
  `AsyncValueBuilder`, `ServiceScope`, `MultiServiceScope`.
- Routing: `FoundationRouteTable` (path and query parameters, authentication
  redirect, deep-link initial stack, not-found page),
  `NavigatorNavigationDriver`, `AuthenticationRouteGuard`,
  `AlwaysAllowUnsavedChangesGuard`.
- Networking: `HttpNetworkTransport` on `package:http` (all platforms,
  abortable timeouts and cancellation, offline mapping); `NetworkClient`
  `baseUri`, `defaultHeaders`, `getJson`/`postJson`/`putJson`/`patchJson`/
  `delete`, `Retry-After` support, and one token refresh and replay on `401`
  through `RefreshableAccessTokenProvider`.
- Auth: `AuthCoordinator.forceRefresh`, `AuthCoordinatorTokenProvider`,
  `OidcAuthorizationRequest.withPkce`, `authorizationUri`,
  `authorizationCodeFrom` (state validation), `pkceS256Challenge`.
- Data: `KeyValueStore` with `InMemoryKeyValueStore` and atomic
  `FileKeyValueStore`; `Sha256BackupChecksum`.
- Observability: `CrashReporter`, `LoggingCrashReporter`,
  `FanOutCrashReporter`, `DebugLogSink`, `FanOutLogSink`.
- Contracts: `Result`, `UuidV4Generator`, `secureRandomString`, `AppVersion`,
  `AppConfiguration.requiresUpdate`.
- UI: `FoundationValidators`, `FoundationAsyncButton`,
  `showFoundationSnackBar`, `FailurePresentation`, destructive confirmation
  dialogs, and Flutter lifecycle and accessibility adapters.
- Bootstrap steps accept a `timeout`; `onStepFailed` reports required and
  optional failures with stack traces; duplicate step IDs are rejected.
- `foundation_preferences.dart` library, included in every preset. The
  minimal preset now also includes observability.
- Example rewritten as a tested starter app; [adapter recipes](docs/RECIPES.md).

### Changed

- Requires Flutter 3.35 / Dart 3.9. CI tests the minimum and current stable.
- Adds `http` and `crypto` dependencies (both maintained by the Dart team).
- `ApiFailureKind.notFound` is new, so exhaustive `switch`es over
  `ApiFailureKind` need a case for it. HTTP 400 now maps to `validation`, 404
  and 410 to `notFound`, 408 to `timeout` (retryable), and 412 to `conflict`.
- A refresh that fails with a retryable `ApiFailure` (offline, timeout,
  server error) keeps the stored session instead of signing the user out.
- `AuthCoordinator` no longer emits identical consecutive snapshots.
- The bootstrap failure screen no longer shows internal step IDs.
- `showFoundationConfirmation` labels default to `FoundationStrings`.

### Fixed

- Compile error on current Flutter stable (`CardTheme` → `CardThemeData`).
- Deprecated `Radio.groupValue` and `DropdownButtonFormField.value` usages.

### Also included (previously unreleased)

- Added the Django-compatible workspace storage v1 contract, privacy policy,
  provider registry, local file adapter, and pluggable SQLite adapter.
- Added Django-compatible consent telemetry, exact schemas, regional policy
  presets, retention caps, privacy-signal handling, and withdrawal purge ports.

## 0.1.0

- Establish product-neutral configuration, bootstrap, auth, network, storage,
  offline sync, backup, observability, platform-service, UI, and testing seams.
- Add deterministic in-memory reference adapters and an example application.
- Add independently importable contracts, app, auth, data, network,
  notification, observability, security, sync, and testing capability libraries
  plus minimal, connected, and offline presets without breaking aggregate
  imports.
