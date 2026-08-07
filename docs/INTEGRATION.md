# Product integration guide

## 1. Compose at the application root

Build one dependency graph at startup. Inject ports into repositories and view
models; do not expose plugin instances to feature folders.

```dart
final database = ProductDriftDatabase(...);
final syncStore = ProductDriftSyncStore(database);
final remoteSync = GeneratedApiSyncAdapter(apiClient);
final coordinator = SyncCoordinator(
  remote: remoteSync,
  store: syncStore,
  clock: const SystemClock(),
);
```

Keep local-only mode by swapping `RemoteSyncPort`/coordinator use, not by
forking feature UI. Account linking must preserve local IDs and enqueue their
first cloud mutations rather than replacing the database.

## 2. Implement SQLite transactions

The concrete database must enable foreign keys and provide forward migrations
from every released schema. A local product write and its outbox append are one
transaction. A pulled page and its cursor are one transaction. Never update the
cursor before all page changes commit.

Run database work off the UI isolate when measured queries become expensive.
Use bounded reactive queries and pagination rather than loading all history.

## 3. Connect the generated API

Implement `NetworkTransport` under the generated OpenAPI client. Preserve
`X-Correlation-ID`, `Idempotency-Key`, normalized failures, timeout, and
cancellation semantics. Retry GET/PUT/DELETE automatically; retry POST/PATCH
only when a stable mutation ID is supplied as the idempotency key.

Do not place Google Sheets, Airtable, customer PostgreSQL, or task-organizer
credentials in this package or the mobile app. The mobile client always talks
to an authorized backend/gateway; server workers own provider credentials and
reconciliation.

## 4. Connect authentication

Use system-browser OIDC Authorization Code + PKCE. Validate state, nonce,
issuer, audience, redirects, and token signature in the selected adapter.
Persist tokens only through the OS secure-store adapter. `AuthCoordinator`
serializes refresh so simultaneous requests do not rotate a refresh token more
than once.

Local-only mode is a first-class auth state. Features must ask server/product
capabilities before showing collaboration—not just whether a user has a token.

## 5. Use the UI surface selectively

Apply `FoundationTheme` as a product baseline and override semantic colors at
the product composition layer. Common fields include labels, validation,
autofill/focus, minimum tap targets, and semantics. Product widgets remain in
the product repository.

`AdaptiveAppShell` switches between phone bottom navigation and rail layout.
Desktop releases require additional adaptive review rather than relying on
this breakpoint alone.

## 6. Validate an adapter

Every production adapter needs:

- contract tests against the matching in-memory reference behavior;
- failure, cancellation, timeout, restart, and concurrency tests;
- redaction verification;
- upgrade/migration fixtures for every released schema;
- real-device tests for secure storage, background work, notifications, deep
  links, poor connectivity, low storage, and interrupted migration.

The example app is an integration/release gate. Replace no fake with a vendor
adapter until its contract tests are green.
