---
name: review-change
description: Review a diff, branch, or PR as a skeptical principal engineer against the project's rules and report ranked, evidence-backed findings. Use after implementing a change and before reporting it complete, or when the user asks for a code review, PR review, or second opinion on changes.
---

# review-change

Find the problems that would hurt in production. Do not write a summary of what the diff does.

## Procedure

1. **Establish scope.** Get the diff (`git diff <base>...HEAD`, or the named PR or files). Read
   the task or PR description so you know the intent.
2. **Run the deterministic checks first** from `PROJECT.md`: format, lint, type check, tests. Record
   the exact commands and results. A failing check is a finding.
3. **Read the rules that apply:** `CORE_RULES.md`, then the stack and role profiles, `PROJECT.md`,
   and `CONTRACTS.md` if wire formats are touched.
4. **Review in this order, and stop to verify each suspicion in the code:**
   1. Correctness: logic errors, edge cases, error paths, concurrency, idempotency, retries.
   2. Data scope and authorization: every new read and write scoped server-side; no client-trusted
      scope; deny by default.
   3. Security and privacy: secrets, injection, unsafe rendering, logging or telemetry of personal
      content, SSRF, token storage.
   4. Data safety: migrations present, reversible or justified, previous-version load tested, no
      user-data loss.
   5. Contracts: public API and cross-runtime compatibility, versioning, CHANGELOG entry.
   6. Layering and dependency direction. For product repos, no framework internals imported.
   7. Tests: would they fail if the rule broke? Are scope, migration, and failure paths covered?
   8. Scope creep: changed lines that do not trace to the task.
   9. Conventions and simplification. Report these last and only if they matter.

## Output

- If the change is sound, say so in one line, list the checks run, and stop.
- Otherwise, findings ranked by consequence. Each has:
  `[blocker|major|minor] path:line — what is wrong → concrete failure scenario → fix`.
- Mark each finding **verified** (you traced or reproduced it) or **suspected** (inferred). Do not
  present a suspicion as fact.
- End with the checks run and their outcomes, and anything you could not verify.

No praise, no restating the diff, no closing encouragement. If you are reviewing your own change
and the fix is in scope, fix it and re-run the checks rather than only listing it.
