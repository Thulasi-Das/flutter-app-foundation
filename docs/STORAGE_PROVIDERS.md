# Implement storage providers in a Flutter product

Use `foundation_storage.dart` for the portable provider contract. Import
`foundation_local_file_storage.dart` only in mobile or desktop targets that use
`dart:io`. Widgets and feature repositories should depend on `WorkspaceStore`,
not on filesystem, SQLite, Google, or Airtable SDKs.

## Create a local workspace

```dart
final registry = StoreRegistry()
  ..register('local_file', const LocalFileStoreFactory());

final descriptor = StoreDescriptor(
  storeId: 'primary',
  workspaceId: 'workspace-123',
  provider: 'local_file',
  privacyMode: PrivacyMode.localOnly,
  dataLocation: DataLocation.device,
  configuration: {'rootPath': appSupportDirectory.path},
);
final store = await registry.create(descriptor);
```

Resolve `appSupportDirectory` through the platform's application-directory API;
do not let an untrusted deep link choose it. The adapter creates a separate
workspace directory and writes records through temporary-file replacement.

For SQLite, implement `WorkspaceSqliteDriverFactory` over the product's reviewed
SQLite package and register `SqliteStoreFactory(driverFactory)`. The driver
returns affected-row counts so optimistic updates remain atomic. The foundation
creates the `foundation_records` schema and exposes identical behavior to the
Django SQLite adapter.

## Store product records

```dart
await store.put(WorkspaceRecord(
  collection: 'notes',
  recordId: 'note-1',
  values: {'title': 'Private note', 'body': '...'},
  version: 1,
  updatedAt: DateTime.now().toUtc(),
));

final page = await store.list(StoreQuery(collection: 'notes', limit: 100));
```

Pass `expectedVersion` on updates. Treat a `StoreErrorCode.conflict` as an
explicit reload or conflict-resolution event.

## Register Google Sheets or Airtable

Use the provider's user OAuth authorization-code flow with PKCE and keep tokens
in OS secure storage. The registry receives only secrets resolved for the
current operation:

```dart
registry.register('airtable', AirtableStoreFactory(productHttpClient));

final store = await registry.create(
  userDescriptor,
  secretLookup: secureProviderCredentials.resolve,
);
```

Keep a stable record ID and version field in the remote table. Do not use row
position as identity. Map provider pagination and errors to the v1 contract,
and declare truthful capabilities.

Never place a customer database password in a Flutter binary or local
configuration. A descriptor with `provider: 'database'` must use
`PrivacyMode.backendBrokered`; its Flutter adapter calls a product backend,
while Django resolves and uses the customer database credentials.

## Product-controlled provider choices

```dart
final choices = visibleProviderOptions([
  const ProviderOption('local_sqlite', recommended: true),
  const ProviderOption('google_sheets'),
  ProviderOption('airtable', enabled: flags.airtableStore),
]);
```

Use these choices to build the onboarding flow. Let users continue locally
without sync. Before copying data to another provider, show the destination,
operator access, encryption, account requirement, and deletion implications,
then obtain explicit confirmation.

## Adapter completion checklist

- Pass the shared schema and `WorkspaceStore` contract tests.
- Scope all operations to the descriptor workspace.
- Preserve stable IDs, versions, unknown product fields, and tombstones.
- Handle offline, expired OAuth, revocation, rate limiting, and partial pages.
- Keep secrets in OS secure storage and redact records and credentials from logs.
- Test export, provider disconnect, account removal, and local secure deletion.
- Do not claim E2EE unless keys remain outside every storage/sync operator.

See the local [architecture guide](ARCHITECTURE.md) and canonical
[v1 JSON schema](contracts/storage-provider-v1.schema.json).
