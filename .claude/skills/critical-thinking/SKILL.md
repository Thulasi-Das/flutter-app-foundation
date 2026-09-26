---
name: critical-thinking
description: Adversarially test a plan, design, conclusion, or report before acting on it. Use for high-stakes or ambiguous decisions (security, data-scope, migrations, public contracts, irreversible operations, architecture trade-offs), when evidence conflicts, or when the user asks to challenge, stress-test, poke holes in, or think critically about something.
---

# critical-thinking

Try to prove the proposal wrong before anyone builds on it. The output is a decision, not a
balanced essay.

## Procedure

1. **Restate the claim precisely** in one sentence: what is being proposed or concluded, and what
   it is for.
2. **List the load-bearing assumptions.** For each, write how you would know it is false, then
   check the ones you can check locally (code, tests, docs, schemas). Mark each as verified,
   refuted, or unverified.
3. **Steelman the strongest alternative,** including "do nothing" and "the simpler version". Say
   what it gets right that the proposal does not.
4. **Pre-mortem.** Assume it shipped and failed six months later. List the three most likely
   causes, ranked by likelihood × impact. Always consider data loss, cross-scope leakage, security
   regression, incompatible contract change, operational burden, and reversibility.
5. **Look for disconfirming evidence** in the repository, not just support. One hard
   counterexample outweighs several agreeing signals.
6. **Decide.**

## Output

- **Verdict:** proceed / proceed with changes / do not proceed / need information. One line.
- **Why:** the two or three reasons that decide it.
- **Required changes or tests** before proceeding, if any.
- **Assumptions:** verified / refuted / unverified, with evidence for each.
- **What would change the verdict:** the specific fact that would flip it.

Be direct. Do not soften a blocker into a consideration. If the proposal survives, say so briefly.
