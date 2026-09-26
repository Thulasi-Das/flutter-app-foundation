# PROJECT.md: flutter-app-foundation

Owned by this repository and never overwritten by the kit installer. Agents load it every session.
It may make kit rules stricter, never looser.

## Identity
- Role: **framework**. Stack: **flutter** (mobile, web, desktop).
- Purpose: one product-neutral Dart/Flutter package. Apps write `main()` and features; the
  foundation supplies the runtime, routing, state, network, auth, storage, sync, telemetry,
  accessible UI, and test fakes.
- Consumers: `accountable-mobile` (git dependency pinned to a commit). Supported range: Flutter
  ≥ 3.35.0 and Dart ≥ 3.9. CI tests the minimum and current stable.

## Commands
The definition of "verified". These mirror `.github/workflows/ci.yml`.

| Step | Command |
|---|---|
| Setup | `flutter pub get` |
| Format | `dart format --output=none --set-exit-if-changed .` |
| Analyze | `flutter analyze --fatal-infos` |
| Test | `flutter test --coverage` |
| Pure-Dart check | `dart run --enable-asserts tool/self_check.dart` |
| Example | `cd example && flutter pub get && flutter analyze --fatal-infos && flutter test` |

## Layout
- `lib/foundation_*.dart`, `lib/flutter_app_foundation*.dart`: public barrel libraries, one per
  capability, plus presets `foundation_preset_{minimal,connected,offline}.dart`. **The public API.**
- `lib/src/<capability>/`: implementation detail that consumers never import.
- `test/`: one suite per capability. `capability_entrypoints_test.dart` guards the barrels.
- `example/`: the tested starter app. `tool/self_check.dart` is the plugin-free runtime smoke check.
- `docs/contracts/*.json`: canonical cross-runtime schemas.

## Authority docs
- `docs/ARCHITECTURE.md` (boundary, libraries, wire conventions, sync state machine, adapters)
- `docs/CONSUMER_IMPLEMENTATION.md`, `docs/INTEGRATION.md`, `docs/RECIPES.md` for consumer-facing
  behaviour. Update them with any public change.
- `docs/SECURITY.md` before auth, storage, backup, notification, or telemetry changes.
  `docs/STORAGE_PROVIDERS.md` and `docs/TELEMETRY.md` cover those capabilities.
- `docs/RELEASING.md`: the compatibility policy and the pull-request gate.

## Project invariants
- Stays one package until independent consumers prove a split. No product screens, product
  records, business permissions, generated API models, or provider mappings.
- No global service locator, static token cache, or global mutable database. Injection is through
  constructors and `ServiceScope`.
- Ship an adapter only if it is plugin-free. Plugin-dependent adapters (secure storage, OIDC,
  SQLite, push, crash vendors) are documented as recipes. In-memory adapters are fakes.
- A new or changed barrel export needs an update to `capability_entrypoints_test.dart`, the docs,
  and `CHANGELOG.md`.
- Breaking auth, database, sync, backup, widget, or design-token changes need a migration guide.
  A foundation update never silently migrates or deletes product data.
- `docs/contracts/*.json` stays byte-identical with `django-app-foundation/docs/contracts/`.
  Change all runtimes together.
- Raise the minimum Flutter version and the CI matrix together. Keep compatibility with the
  consumer's pinned toolchain in mind; `accountable-mobile` runs Flutter 3.44.
