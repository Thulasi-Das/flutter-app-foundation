# LLM Integration

> Vendored from `personal-ai-source-of-truth`. Routed from `CORE_RULES.md` → Task routing.

Guidance for **code we write that calls the Anthropic or OpenAI APIs**, and for upgrading that code
across model versions.

This is routed, not always-on. Load it only for model selection, prompt caching, reasoning/thinking
budgets, batching, streaming, structured output, SDK migrations, or model-version upgrades. Ordinary
product work does not need it.

---

## Model selection

**Do not hardcode model names in rule files or prose guidance.** The dated snapshot below is the
one exception, and it exists to be re-verified. Model lineups change every few months and stale names in rule files are worse
than no names at all — they get followed.

Check the vendor's current model list before selecting or upgrading a model:

- Anthropic: https://platform.claude.com/docs/en/about-claude/models/overview
- OpenAI / Codex: https://learn.chatgpt.com/docs/models

Select by role, not by remembered name:

| Role | Pick |
|---|---|
| Complex reasoning, long-running agents, architecture-scale work | The vendor's most capable current tier |
| Balanced default for everyday work | The vendor's mid tier |
| Latency-sensitive, high-volume, extraction or classification | The vendor's fast/low-cost tier |

Record the concrete model string in the calling code and in that project's own config — one place,
not scattered across call sites.

### Lineup snapshot

Snapshot only, and dated per vendor. Verify against the links above before acting on it.

- Anthropic (checked 26 Sep 2026): Claude Fable 5.1, Claude Opus 5.5, Claude Sonnet 5, Claude
  Haiku 4.5. Extended-thinking support is **not** uniform across a lineup, so confirm it per model
  before enabling `thinking`.
- OpenAI Codex (carried over from the 21 Aug 2026 review, not re-verified): GPT-5.6 Sol, GPT-5.6
  Terra, GPT-5.6 Luna, and `gpt-5.3-codex-spark` as a restricted research preview.

---

## Model upgrades

Applies to both vendors.

- Inventory current model usage across all call sites before changing anything.
- Identify the prompt surfaces directly tied to the old model's behavior.
- Preserve explicitly requested target models.
- Update only model strings plus directly coupled prompts, unless the user expands scope.
- Re-evaluate `max_tokens`, reasoning effort, thinking budget, and verbosity during an upgrade.
  Do not assume higher effort or longer output is better after an upgrade.
- Preserve existing reasoning settings on the first upgrade pass when they are visible. Do not add
  new reasoning settings only because the repo omits them, unless current vendor docs require it.
- Leave unchanged unless explicitly asked: historical docs, examples, tests, eval baselines,
  provider comparisons, pinned fallback models, and ambiguous older model usages.
- Treat these as **blocked or confirmation-needed**, never folded into a model-and-prompt upgrade:
  SDK or API migrations, provider migrations, tool-definition changes, tool-handler rewiring,
  structured-output schema changes, new streaming or batching patterns, and new `phase`
  implementation work.

---

## Anthropic API

- Always apply prompt caching (`cache_control`) to large, stable context blocks: system prompts,
  retrieved docs, long tool outputs. Cache hit rate is observable — verify it during review.
- Extended thinking (`thinking: {type: "enabled", budget_tokens: N}`) must be used intentionally.
  Set a budget matched to task complexity and verify that response quality justifies the token cost.
  Confirm the target model supports it before enabling.
- For batch workloads, use the Batch API. Do not simulate batching with concurrent individual calls
  unless the Batch API is unavailable for the model or feature in use.

---

## OpenAI Responses API

- When assistant items are manually replayed, preserve assistant item `phase` values exactly.
- Use `phase: "commentary"` for intermediate user-visible updates and `phase: "final_answer"` for
  the completed response, when the application explicitly manages phases. Do not add `phase` to
  user messages.
- The requirement to preserve `phase` metadata was established for the `gpt-5.3-codex` harness,
  where dropping it degraded long-running coding behavior. Re-confirm against current docs before
  asserting it for a newer model.

---

## Long-running agent workflows

Vendor-neutral.

- Use compaction intentionally. Compacted state must preserve completed actions, active assumptions,
  tool outcomes, blockers, and the next concrete goal.
- When truncating large tool outputs, preserve the beginning and the end with an explicit
  middle-truncation marker. Do not silently drop context.

---

## LLM features inside products

Vendor-neutral rules for product code that calls a model.

- Call models through one provider adapter owned by the project. Features never import a vendor
  SDK directly, and the concrete model string lives in that adapter's configuration.
- Version prompts like code: keep them in files, review them, and record the prompt version with
  each call's telemetry.
- Track tokens and cost per call, tagged with the data scope and feature, without logging content.
- Mask or drop PII and secrets before sending data to a model. Never send credentials, raw tokens,
  or another scope's data.
- Treat model output as untrusted input. Validate structured output against a schema before use,
  and never execute it, render it as HTML, or use it as a query or path without validation.
- Set timeouts and bounded retries. Degrade to a non-LLM path when the provider is unavailable.
- Evaluate before shipping a prompt or model change: a fixed eval set with expected properties,
  compared against the current baseline.
