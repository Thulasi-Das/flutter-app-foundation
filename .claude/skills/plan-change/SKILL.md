---
name: plan-change
description: Produce an outcome-first, verifiable implementation plan before a non-trivial code change. Use when a request spans several files or layers, touches a public contract, schema, persisted data, data-scope isolation, authorization, or sync, or when the user asks for a plan, design, or PR breakdown. Skip it for one-line fixes.
---

# plan-change

Produce a plan that someone else could execute and verify without asking you questions. No code
unless the user asked for it.

## Inputs to read first

1. `CORE_RULES.md`, `PROJECT.md`, and the stack and role profiles named there (under `.ai/` in
   consumer repositories, `ai/` in the kit).
2. The code the change touches: entry points, immediate callers, existing tests, and the closest
   existing feature that does something similar. Copy its shape.
3. `CONTRACTS.md` if HTTP, sync, storage, telemetry, or errors are involved.

Stop and report if data-scope enforcement, the owning layer, or a contract owner is unclear after
reading.

## Output (in this order, terse)

1. **Outcome.** One or two sentences on the end state, from the user's point of view.
2. **Success criteria.** A numbered list. Each item can be checked by a command, a test, or an
   observable behaviour.
3. **Assumptions and open questions.** Each assumption is labelled. Each question offers named
   options and your recommendation.
4. **Impact inventory.** List only what applies:
   - layers and files touched (boundary, business logic, data access, schema, UI)
   - public API or cross-runtime contract changes, and whether each is compatible
   - persisted state: migration, defaults, previous-version load, import/export
   - data scope: how scope is resolved and enforced on each new read and write
   - security and privacy: authz, secrets, logging, telemetry fields
   - offline and sync behaviour; accessibility for UI
5. **Plan.** Ordered steps. Each step names its verification check.
6. **Test plan.** The tests that would fail if the rule were broken, including the scope-boundary
   and migration tests when relevant.
7. **PR slices.** Split when the change exceeds about 400 changed lines or mixes contract, backend,
   and UI. Typical order: contracts/schema, then backend, then client, then docs/config. Each slice
   builds and passes tests on its own.
8. **Out of scope.** What you will deliberately not change.

## Self-check before returning

- Every criterion is verifiable, and every step traces to a criterion.
- No new abstraction where an existing pattern fits.
- No step weakens a Core invariant. If one must, it is a stop condition, not a step.
