# Testing and release policy

## Compatibility

- Semantic versioning; `0.1.x` may refine APIs with documented migrations.
- Declare and test the supported Flutter/Dart/mobile/desktop matrix.
- Product apps pin compatible package versions.
- Breaking auth, database, sync, backup, widget, or design-token changes require
  a migration guide and consumer fixture.
- A foundation update never silently migrates or deletes product data.

## Pull-request gate

1. format and analyze with strict inference/casts/raw types;
2. unit, widget, migration, sync, backup, and example tests;
3. build the example application;
4. dependency, secret, SAST, license, and platform-manifest checks;
5. consumer-contract fixture against at least one product;
6. accessibility semantics, keyboard, text scale, contrast, and reduced-motion
   review for changed UI;
7. changelog and migration note when public behavior changes.

## Product release gate

Run real-device Android/iOS tests covering upgrade from every supported local
schema, airplane/poor-network, background/resume, secure storage, notification,
deep link, backup/restore, low storage, interrupted migration, accessibility,
startup, memory, and battery. Use internal testing, closed beta, staged
percentage rollout, observability, and reversible optional feature flags.

Publish immutable signed artifacts from protected CI only. Signing keys and
store credentials remain outside source control.
