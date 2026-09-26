# CONTRACTS.md

Cross-runtime wire conventions shared by the Django, TypeScript, and Flutter foundations and every
product built on them. This is a summary for agents. The canonical definitions are:

- `docs/contracts/*.json` in `django-app-foundation` and `flutter-app-foundation`. The two copies
  must stay byte-identical.
- `docs/contracts.md` in `typescript-web-foundation`
- a product's own OpenAPI document (for example `accountability/contracts/openapi/openapi.yaml`)

If this file and a schema disagree, the schema wins. Report the drift.

## Rules

- These are transport contracts, not domain schemas. Products add fields; they never remove,
  rename, or change the meaning of a shared field.
- An incompatible change needs a new contract version, all three runtimes updated, and an upgrade
  window during which old clients keep working. Never change one runtime alone.
- Python uses snake_case internally, but wire dataclasses keep the camelCase field names below so
  they match the TypeScript and Dart clients.
- Generated API clients preserve these fields exactly. Hand-written clients pin header and path
  names in one module.

## HTTP

| Concern | Convention |
|---|---|
| Correlation | `X-Correlation-ID` request/response header. Accept if valid, otherwise mint one. Echo it in errors and logs. |
| Retry-safe writes | Mutating endpoints accept `Idempotency-Key`. Results are stored per data scope. Reusing a key with a different request fingerprint is rejected. |
| Versioning | Public APIs live under `/api/v1/`. Operational probes are `/healthz` (alive) and `/readyz` (dependencies ready). |
| Scope header | `X-Workspace-ID` is a *request* for scope. The server resolves it against verified membership and never trusts it on its own. |

## Error envelope

```json
{ "code": "stable_machine_code", "message": "Safe user-facing summary",
  "correlationId": "request-id", "details": {}, "retryable": false }
```

- `code` is stable and machine-readable; clients branch on it, never on `message`.
- `message` is safe to show. No stack traces, SQL, provider payloads, credentials, or internal IDs.
- `retryable` tells clients and sync coordinators whether an automatic retry is allowed.

## Mutation envelope (offline sync)

Required: `mutationId`, `workspaceId`, `entityType`, `entityId`, `operation`, `baseVersion`,
`payload`, `occurredAt`.

- `mutationId` is the idempotency identity. Servers deduplicate on it.
- Actor, device, schema version, attempt count, and local delivery state are additive metadata.
- Timestamps are never record identity.
- The server answers each mutation as applied, conflict, or rejected. Conflicts stay visible to
  the user; they are never silently resolved by last-write-wins.
- Clients write the local change and the outbox entry in one transaction, then push bounded,
  ordered batches per workspace.

## Storage provider descriptor (`storage-provider-v1`)

Required: `contractVersion` (`"1.0"`), `storeId`, `workspaceId`, `provider`, `privacyMode`
(`local_only` | `direct_user_provider` | `backend_brokered` | `managed`), `dataLocation`
(`device` | `user_cloud` | `user_infrastructure` | `managed_service`), `configuration`.
Optional: `displayName`, `secretReference`.

- `configuration` holds non-secret settings only. Credentials are reached through an opaque
  `secretReference` that only the authorized runtime resolves.
- Clients never connect directly to a customer database. That is `backend_brokered`.

## Telemetry (`telemetry-v1`)

Event fields: `contractVersion`, `eventId`, `eventName` (`^[a-z][a-z0-9_.-]{2,63}$`), `purpose`,
`dataClasses`, `attributes` (scalar values only), `occurredAt`, `subjectKey` (pseudonymous), and an
optional `sessionId`.

- Purposes: `reliability`, `product_analytics`, `product_improvement`, `personalization`,
  `commercial_insights`. Every purpose needs consent; telemetry is off by default.
- Withdrawing consent purges locally buffered events for that purpose.
- Never collect raw user content (task text, notes, moods), URLs, IP addresses, precise location,
  raw user IDs, secrets, stack traces, or message content.
- Retention caps and regional profiles live in `telemetry-policy-presets-v1.json`.
