# Architecture

## Boundary

This repository is one product-neutral Dart/Flutter package. It should remain a
single package until independently versioned consumers prove a split is useful.
Product screens, product records, business permissions, generated API models,
and provider-specific mappings remain in product repositories.

```text
View/widgets -> view model -> product repository
                                  |-- local database adapter
                                  |-- outbox/sync coordinator
                                  `-- generated remote API adapter
```

Views never read raw HTTP responses or database rows. Offline-capable product
repositories commit the local read-model change and canonical outbox mutation
in one real SQLite transaction, then render from local data immediately.

## Libraries

- `foundation_contracts.dart` exports clocks and ID-generation ports shared by
  multiple capabilities.
- `foundation_app.dart`, `foundation_auth.dart`, `foundation_data.dart`,
  `foundation_storage.dart`,
  `foundation_telemetry.dart`,
  `foundation_network.dart`, `foundation_notifications.dart`,
  `foundation_observability.dart`, `foundation_security.dart`, and
  `foundation_sync.dart` are independently adoptable capability libraries.
- `foundation_testing.dart` exports deterministic fakes and shared test
  primitives. The widget harness remains on the UI surface.
- `flutter_app_foundation_ui.dart` exports Flutter themes, fields, state views,
  adaptive shell, bootstrap gate, and widget-test harness.
- `foundation_preset_minimal.dart`, `foundation_preset_connected.dart`, and
  `foundation_preset_offline.dart` are curated re-export compositions.
- `flutter_app_foundation.dart` remains the backward-compatible aggregate core
  entry point.
- `lib/src/**` is implementation detail. Consumers import only barrel files.

Dependency injection is explicit through constructors. There is no global
service locator, static token cache, or global mutable database.

Capability libraries and presets remain in one package and version line. A
capability becomes a separate pub package only after independent consumers,
plugin dependencies, ownership, or release cadence make separate versioning
valuable.

## Shared wire conventions

All clients and servers use:

- `X-Correlation-ID` for request/support correlation;
- `Idempotency-Key` for retryable writes;
- normalized errors:

```json
{
  "code": "stable_machine_code",
  "message": "Safe user-facing summary",
  "correlationId": "request-id",
  "details": {},
  "retryable": false
}
```

The canonical mutation abstraction carries `mutationId`, `workspaceId`,
`entityType`, `entityId`, `operation`, `baseVersion`, `payload`, and
`occurredAt`. Product adapters may add actor and device IDs, but must not remove
the shared fields. Timestamps are never used as record identity.

## Offline sync state machine

1. Product repository validates a command.
2. SQLite transaction updates local record and appends a pending mutation.
3. UI observes the local record immediately.
4. Coordinator takes one bounded, ordered batch per workspace.
5. Remote push deduplicates by mutation ID and reports applied/conflict/reject.
6. Local statuses are committed; retryable transport failures return sending
   entries to pending with a future retry time.
7. Pull pages are applied with their cursor in one transaction.
8. Explicit conflicts remain action-required; they are never hidden by generic
   last-write-wins.

Connectivity is only a hint. A successful request is the only proof of network
reachability. Background schedules are opportunistic because mobile operating
systems control when work runs.

## Adapters a product supplies

| Port                          | Suggested first adapter              | Foundation guarantee                       |
| ----------------------------- | ------------------------------------ | ------------------------------------------ |
| `LocalDatabase` / `SyncStore` | Drift/SQLite                         | migrations and atomic cursors/outbox       |
| `NetworkTransport`            | Dio or `package:http`                | typed envelope, retry policy, cancellation |
| `OidcClient`                  | maintained AppAuth-compatible plugin | Authorization Code + PKCE                  |
| `SecureStorage`               | Keychain/Keystore/credential vault   | secrets never enter SQLite/preferences     |
| `Telemetry` / `LogSink`       | OpenTelemetry/crash vendor           | allowlisted metadata only                  |
| `NotificationService`         | APNs/FCM adapter                     | opaque payloads and permission seam        |
| `BackupChecksum`              | maintained SHA-256 package           | verified, staged restore                   |
| `BackupEncryption`            | reviewed platform/crypto library     | no home-grown cryptography                 |

In-memory adapters are deterministic fakes/reference behavior, not production
storage or security implementations.

## Desktop evolution

Domain repositories, local storage, sync, themes, localization, auth, and most
views can be shared. Desktop products still need explicit window sizing,
multi-window, keyboard/focus, OS vault, file, notification, updater, signing,
single-instance, and database-locking adapters. Enlarging phone widgets is not
a desktop architecture.
