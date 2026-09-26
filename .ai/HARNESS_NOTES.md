# HARNESS_NOTES.md

Harness-specific execution notes. Read **only** the section for the harness you are running in.
Everything that applies to all harnesses lives in [CORE_RULES.md](CORE_RULES.md). Nothing here may
weaken, override, or reinterpret it.

---

## Claude Code

Entrypoint: `CLAUDE.md`. It imports `CORE_RULES.md` (and `PROJECT.md` in consumer repositories)
with `@` lines, so those are already in context. Do not re-read them.

### Tool discipline
- Read a file before editing it. Use targeted edits; rewrite whole files only when they are new or
  replaced wholesale.
- Use absolute paths in shell commands; do not rely on an implicit working directory.
- Batch independent reads and searches in one turn.
- Track multi-step work with the harness's task list; mark items done as they finish.
- Use a search subagent only for broad sweeps that would take more than three queries; use `rg`
  directly for targeted lookups.
- Skills live in `.claude/skills/<name>/SKILL.md` and are invoked by name.

### Progress and asking
- For long, tool-heavy tasks, emit short updates at key steps. No long upfront plans.
- When `CORE_RULES.md` says ask, use a multiple-choice question with named options.

### Permissions
- Shared, safe defaults live in `.claude/settings.json` (committed). Machine-specific grants such
  as extra trusted directories go in `.claude/settings.local.json` (gitignored), with paths taken
  from `ai/PATHS.md` in the kit.

---

## Claude Code on the web (cloud sessions)

Same as **Claude Code**, plus:
- The container is ephemeral and each repository is cloned fresh. Sibling repositories and local
  volumes from `PATHS.md` usually do not exist. That is why the kit is vendored into `.ai/`
  rather than referenced by path: rely on the vendored copy, never on a sibling checkout.
- Work that is not committed and pushed to the session's branch is lost when the container ends.
- Do not open a pull request unless asked.
- User-level files (`~/.claude/CLAUDE.md`) are not present, so personal context is absent. Do not
  guess preferences it would have supplied.

---

## Codex CLI

Entrypoint: `AGENTS.md`. Codex concatenates `AGENTS.md` files up to a combined size limit
(32 KiB by default) and silently drops the rest, so routers stay small and rule bodies are read
on demand with tools.

### Tool discipline
- Use `apply_patch` for manual edits and shell commands with an explicit working directory.
- Use the plan tool for multi-step work and parallel calls for independent reads or searches.
- Skills: read `.claude/skills/<name>/SKILL.md` and follow it. The directory name is historical;
  the files are harness-neutral.

### Progress and effort
- Give short updates only when the harness supports commentary; otherwise do not force preambles.
- Reasoning effort is a per-run choice. Start at the default and raise it for architecture, feature
  design, or cross-module work. Higher effort is not automatically better.

---

## Cowork

Entrypoint: `CLAUDE.md`. Cowork runs in an isolated container. It is not a checkout of the
repository, and its shell cannot see the local filesystem.

### Reaching the repository
- The repository is reachable only as a connected folder through the device bridge. Do not assume
  `git` write access, a configured remote, or a clean working tree; read its state before editing.
- The bridge mount path is not stable. Never hardcode it; use the names in the kit's `PATHS.md`.

### Deliverables and scope
- A file produced in the container does not exist for the user until it is delivered. Deliver it,
  then write it back into the connected folder. Keep scratch files out of the connected folder.
- Do not commit on the user's behalf unless asked.
- Cowork suits research, design docs, plans, reviews, and drafting. It does not suit building,
  running tests, or executing the codebase: route that to Claude Code or Codex and say so.

### Asking
- Sessions may be unattended. If a decision is needed and nobody is present, take the most
  reasonable interpretation, state it at the top of the output, and continue. Stop only when every
  path is irreversible.

---

## Personal context (all harnesses)

`about-me.md` and `writing-style.md` are canonical in the kit's `ai/`. The kit's
`ai/sync-personal-context.sh` writes `about-me.md` into `~/.claude/CLAUDE.md` and
`~/.codex/AGENTS.md` inside a marked block, and adds a pointer to `writing-style.md`. They are not
vendored into consumer repositories, some of which are public. Read `writing-style.md` only when
drafting something the user will send as themselves.
