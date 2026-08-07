# Security and privacy contract

## Non-negotiable defaults

- OIDC uses Authorization Code + PKCE in the system browser.
- Access, refresh, and ID tokens live only in OS secure storage.
- Tokens, email, provider IDs, database DSNs, record content, task titles,
  mood, notes, blockers, and notification content never enter logs or metrics.
- Structured logging uses an allowlist. Unknown attributes are dropped.
- Imported backups, files, web URLs, notifications, and deep links are
  untrusted input and validated before use.
- Backup integrity uses a maintained SHA-256 implementation; optional
  encryption uses a reviewed platform/crypto adapter with an explicit recovery
  key flow. The `TestChecksum` fake is never a production option.
- Device root/jailbreak signals inform risk decisions; they are not proof of
  compromise or trust.
- Feature flags may disable optional behavior but never bypass authorization,
  migration, minimum-version, or privacy controls.

## Data classification

| Class | Mobile examples | Required handling |
| --- | --- | --- |
| Restricted | tokens, encryption keys | OS secure store only |
| Sensitive personal | mood, notes, health data | private, encrypted where threat model requires |
| Shared personal | explicitly shared content | server authorization and audit |
| Operational | opaque IDs, versions, sync phase | minimized/pseudonymized telemetry |
| Public | design tokens, help strings | normal package distribution |

Product code must classify every persisted column and notification payload.
Category names such as Health or Work do not imply visibility.

## Adapter review checklist

- exact OIDC redirects, state/nonce validation, refresh rotation and revocation;
- platform credential-store accessibility/backup settings;
- TLS validation and enterprise certificate policy without insecure bypasses;
- SQLite encryption requirements and keys separated from the database;
- privacy-screen and lock-screen preview behavior;
- clipboard expiry for secrets;
- deep-link scheme/host/path/signature allowlist;
- backup checksum before decrypt, staging verification, atomic swap, and prior
  database retention until success;
- telemetry consent/deletion and human-reviewable diagnostic export;
- dependency, secret, license, SAST, binary, and signing checks in protected CI.

Report vulnerabilities privately to the repository owner. Do not place secrets,
real personal data, or provider credentials in issues or fixtures.
