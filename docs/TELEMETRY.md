# Add consent-governed telemetry to a Flutter product

Import `foundation_telemetry.dart`. Flutter performs the first permission and
schema gate before transmission; Django repeats the gate with server-owned
identity and consent state.

## 1. Select policy and register events

```dart
final policy = ConsentTelemetryPolicy.forCountry(
  account.privacyCountryCode,
  policyVersion: 'privacy-2026-08',
  noticeVersion: 'telemetry-notice-4',
);

final registry = TelemetryEventRegistry()
  ..register(TelemetryEventSpec(
    name: 'feature.opened',
    purpose: TelemetryPurpose.productAnalytics,
    dataClasses: {TelemetryDataClass.interaction},
    attributes: const {
      'featureKey': AttributeRule(AttributeKind.string, maxLength: 64),
      'entryPoint': AttributeRule(
        AttributeKind.string,
        allowedValues: {'navigation', 'shortcut', 'deep_link'},
      ),
    },
    retentionDays: 90,
  ));
```

Use a trusted account/tenant setting or deployment policy for the country code.
Do not collect device location or IP address to choose a preset.

## 2. Present granular choices

Show separate, initially-off controls for reliability, product analytics,
product improvement, personalization, and commercial insights. Explain the
exact data categories, purpose, recipients, retention, and withdrawal path.
Refusing voluntary telemetry must not block normal application use.

Persist each `ConsentReceipt` in protected local storage and synchronize the
decision to the authenticated backend. If offline, a withdrawal takes effect
locally immediately; queue the server withdrawal ahead of future telemetry and
do not resume that purpose while delivery is pending.

## 3. Compose the local gate

```dart
final telemetry = ConsentGatedTelemetry(
  policy: policy,
  registry: registry,
  consents: productConsentStore,
  sink: ProductTelemetryApiSink(apiClient),
  clock: systemClock,
);
```

`ProductTelemetryApiSink` sends accepted events to a dedicated authenticated
endpoint. It must use bounded batches, retry only safe failures, avoid background
transmission after logout/withdrawal, and never add device identifiers or SDK
auto-collection outside the registered event.

## 4. Record a product event

```dart
final outcome = await telemetry.record(ConsentTelemetryEvent(
  eventId: productIds.next(),
  eventName: 'feature.opened',
  purpose: TelemetryPurpose.productAnalytics,
  dataClasses: {TelemetryDataClass.interaction},
  attributes: const {
    'featureKey': 'advanced_reports',
    'entryPoint': 'navigation',
  },
  occurredAt: DateTime.now().toUtc(),
  subjectKey: await pseudonymousSubject.current(),
));
```

Use a random, rotatable installation pseudonym from OS secure storage or a
server-issued scoped pseudonym. Never embed a server HMAC key or send a raw user,
email, advertising, vendor, or hardware identifier.

## 5. Capture exceptions safely

Your Flutter error boundary may emit a registered reliability event containing
only normalized exception type, stable error code, handled state, component,
app version, platform, and release. Do not forward `exception.toString()`, raw
stack traces, routes with parameters, filenames, widget text, network bodies,
URLs, or local database values.

Keep an explicit, user-reviewed diagnostic export as a separate support flow if
raw details are genuinely necessary.

## 6. Withdraw

```dart
await telemetry.withdraw(withdrawnReceipt);
```

The framework saves the withdrawn state before requesting a purpose-scoped
purge. The product sink must make the backend purge durable and expose failures
without re-enabling collection.

## Production checklist

- Privacy choices are unticked, purpose-specific, accessible, and reversible.
- Policy and notice versions match the Django backend.
- No analytics/crash SDK auto-collects before the local gate.
- Background isolates and native crash handlers obey the same effective consent.
- Logout, account switch, reinstall, and multi-device withdrawal are tested.
- Offline queues encrypt accepted events and delete revoked-purpose events.
- Server rejection is final; the client does not reroute rejected telemetry.
- Commercial insights remain disabled unless deliberately enabled and separately
  granted; marketing communications use separate permissions.

See the [architecture](ARCHITECTURE.md), canonical
[telemetry schema](contracts/telemetry-v1.schema.json), and
[policy presets](contracts/telemetry-policy-presets-v1.json).
