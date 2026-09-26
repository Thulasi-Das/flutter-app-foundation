# Role profile: framework

Applies to product-neutral foundation repositories (`django-app-foundation`,
`typescript-web-foundation`, `flutter-app-foundation`, and any future `*-foundation`). The kit's
`docs/architecture/framework-development.md` is the long-form reference.

## What a framework is for

A framework supplies cross-cutting production concerns (configuration, API boundary, identity
verification, data scope, authorization ports, persistence helpers, async work, sync, storage,
telemetry, observability, security, and test fakes) so products write only their domain.

## Rules

- **Product-neutral.** No product domain models, product names, product constants, business rules,
  or product-specific error messages. If an example needs a domain, use a neutral one (`Project`,
  `Item`, `Todo`).
- **One-way dependencies.** A framework never imports product code. Inside the framework,
  lower-level capabilities never depend on higher-level ones.
- **Ports and adapters.** Define small interfaces for vendor-specific concerns. Ship an adapter only
  when it needs no plugin or heavy dependency; otherwise document a recipe and let the product
  supply it. In-memory adapters are fakes, not production implementations.
- **Explicit composition.** No hidden globals, service locators, or import-time side effects.
  Presets are re-export compositions or declarations of intent; they never construct services.
- **Public surface is the contract.** Only barrels, capability subpaths, and documented modules are
  public. Anything under `src/` or private modules can change without notice. Adding an export is a
  contract decision.

## Contract changes

A new or changed public abstraction must answer, in the PR and the docs:
1. what it provides and what it expects (inputs, configuration, hooks);
2. what it guarantees (side effects, failure modes, thread or async safety);
3. what it deliberately does not handle, and so what the product must do;
4. whether it touches a cross-runtime contract. If it does, update all three runtimes and
   [CONTRACTS.md](../CONTRACTS.md).

- Semantic versioning. Breaking changes need a major version bump, a `CHANGELOG.md` entry with a
  migration note, and a deprecation path where feasible.
- Keep capabilities in one package and version line until independent consumers, dependency
  weight, ownership, or release cadence prove a split is needed.
- Every behaviour change updates `CHANGELOG.md` under the unreleased section.

## Quality bar

- Tests run in isolation from any product and cover failure modes as well as the happy path.
- The example or reference app compiles and runs in CI, and shows the documented usage.
- Security-relevant defaults are safe (deny by default, fail fast on missing secrets, redact
  logs). Loosening one needs an explicit opt-in and a documented reason.
- Docs, the public API reference, and the consumer implementation guide change in the same PR
  as the code.
