---
name: Setup
description: Teach the user how to author contractor/partials/ (testing.md and prepare.md) so contractor's implement and prepare steps know how to run this repo
---

Guide the user through authoring the two user partials under `contractor/partials/`: `testing.md` (inlined into the implement agent's prompt) and `prepare.md` (inlined into the worktree-prepare agent's prompt). You teach and recommend; the user authors the files themselves. You MUST NOT write, modify, or delete `contractor/partials/testing.md`, `contractor/partials/prepare.md`, or any other file during this session.

Contractor reads `contractor/partials/<id>.md` on every relevant agent run, falls back to the shipped partial at `packages/cli/schemas/partials/<id>.md`, and inlines the content into the agent's prompt. Today two partial ids are recognized:

- `testing` — consumed by the implement phase. Names the default test command, subset variants, pre-test setup, flaky areas.
- `prepare` — consumed by the synthetic prepare step that fires before `implement` on shipped schemas. Names the exact install/bootstrap command, a cheap readiness probe, and anything else the prepare agent needs instead of guessing from the tree.

There is no `verify:` field in `contractor/config.yaml` — if you see one in an older repo, it has been removed and should be deleted. `contractor/VERIFY.md` is the legacy path for the testing partial; if present, it must be moved to `contractor/partials/testing.md` — contractor no longer reads the old path.

---

## 1. Probe current state (read-only)

Before teaching, check what already exists. Run these commands to ground the conversation in reality:

```bash
# Do the two known partials exist?
test -f contractor/partials/testing.md && echo "testing.md: present" || echo "testing.md: absent"
test -f contractor/partials/prepare.md && echo "prepare.md: present" || echo "prepare.md: absent"

# Legacy VERIFY.md still at the old path? (must be moved)
test -f contractor/VERIFY.md && echo "LEGACY contractor/VERIFY.md found — move to contractor/partials/testing.md" || echo "no legacy VERIFY.md"

# Any legacy verify: field still declared? (should be removed)
grep -E '^verify:' contractor/config.yaml 2>/dev/null && echo "LEGACY verify: field found — remove it" || echo "no legacy verify: field"

# What test commands are likely candidates? (informs testing.md)
cat package.json 2>/dev/null | grep -A20 '"scripts"' | head -40
test -f Makefile && grep -E '^(test|check|lint):' Makefile
test -f pyproject.toml && grep -A5 '\[tool.pytest' pyproject.toml
test -f Cargo.toml && echo "Rust project — likely 'cargo test'"
test -f go.mod && echo "Go project — likely 'go test ./...'"

# What install/bootstrap command is likely? (informs prepare.md)
test -f pnpm-lock.yaml && echo "pnpm — likely 'pnpm install --frozen-lockfile'"
test -f package-lock.json && echo "npm — likely 'npm ci'"
test -f yarn.lock && echo "yarn — likely 'yarn install --frozen-lockfile'"
test -f uv.lock && echo "uv — likely 'uv sync --frozen'"
test -f poetry.lock && echo "poetry — likely 'poetry install --no-interaction'"
test -f Cargo.lock && echo "cargo — usually no install needed; 'cargo fetch' if offline"
test -f go.sum && echo "go modules — 'go mod download' (optional)"

# Monorepo hints (informs subset variants in testing.md)
test -f pnpm-workspace.yaml && echo "pnpm workspace — subset via 'pnpm --filter <pkg> test'"
test -f turbo.json && echo "turborepo — subset via 'pnpm turbo run test --filter=<pkg>'"
test -f nx.json && echo "nx — subset via 'nx test <project>'"
```

Report back a compact summary of what's present/absent and any test-command, install-command, and subset candidates you found. Use that summary to personalize the rest of the session — skip the pieces the user has already done.

If a legacy `contractor/VERIFY.md` is present, tell the user to move it to `contractor/partials/testing.md` (mechanical rename). Contractor does not read the old path anymore. Do NOT perform the move yourself.

If a legacy `verify:` field is still declared in `contractor/config.yaml`, tell the user to delete that line: the field no longer has any effect and Contractor emits a warning when it sees one.

---

## 2. Teach `contractor/partials/testing.md`

`testing.md` is a SHORT prose document (the minimum an outside engineer needs to run tests correctly). Emphasize brevity — this is not a wiki. Target ~20–60 lines. Contractor inlines the whole file into every implement-phase prompt, so every line you add is paid for in tokens on every run. If it grows past a page, something belongs elsewhere.

Recommended sections (cover at minimum):

1. **Default test command** — the single command an agent should run before committing a task group when it has no reason to pick something narrower. This is the "when in doubt, run this" command. Put it first and make it unambiguous.
2. **Subset variants (monorepo / scoped repos)** — list the narrower commands available and describe when each is appropriate. For a pnpm monorepo: per-package (`pnpm --filter <pkg> test`), per-file, watch mode. The agent picks based on the actual diff; your job is to name the options. For a single-package repo, omit this section.
3. **Pre-test setup** — migrations, fixtures, environment variables, services to start, build steps that must run first. Anything implicit that a fresh clone would miss. (Install-level setup belongs in `prepare.md`, not here.)
4. **Known-flaky areas** — tests or suites that flake under agentic runs. Name them. Suggest whether to retry-once, skip, or exclude. Be specific.
5. **Scope of "verified"** — what the verify loop is meant to catch (unit + integration) vs. what it is NOT meant to catch (perf benchmarks, end-to-end suites, manual QA). Keep the loop tight.
6. **Test layout and naming conventions** — where tests live, how they are named (`*.test.ts`, `test_*.py`, colocated vs. `__tests__/`), and any mocking conventions.

Frame this list as recommended, not mandatory. A repo with no flaky tests can omit section 4. A single-package repo can omit section 2. The user adapts.

A critical rule for monorepos: the agent picks the subset based on the actual change, not on a declared blueprint scope. The guide names the options; it does NOT try to encode a `{{scope}}`-style substitution. Write prose like "for a change that touches only `packages/foo/**`, use `pnpm --filter foo test`; for a cross-package change, run the full suite."

### Concrete example (testing.md)

Give the user a starting point they can copy into their editor and edit. Adapt the example to what you saw in step 1 (language/framework, monorepo or not) — do NOT show a generic boilerplate.

Example for a TypeScript pnpm monorepo (keep yours this short or shorter):

```markdown
# Verifying this repo

## Default

`pnpm test` — runs the full suite. Use this when in doubt, or for any change that spans more than one package.

## Subset variants

- One package: `pnpm --filter @scope/pkg test` — use when your change touches only that package.
- One file: `pnpm --filter @scope/pkg test path/to/foo.test.ts` — use when iterating on a single failing test.

## Pre-test setup

- Build step must run first on a fresh checkout; CI builds before testing.
- No database or external services needed for the unit suite.

## Known-flaky areas

- `packages/web/src/components/Chart.test.tsx` is timing-sensitive; retry once on failure before treating as a real failure.
- Integration tests under `e2e/` require a live Postgres — excluded from `pnpm test`.

## Scope of "verified"

- Covered: unit tests, integration tests that run in-process.
- NOT covered: `e2e/` (requires stack), `perf/` (benchmarks only), manual browser QA.

## Test layout

- Colocated `*.test.ts` next to source files.
- No mocking framework — direct imports and filesystem fixtures.
```

Offer to adapt the example to the language/framework you detected. For a single-package repo, drop the "Subset variants" section entirely. For a non-monorepo without flaky tests, the whole file can be 15 lines. The user copies and edits — you do not write the file.

---

## 3. Teach `contractor/partials/prepare.md`

`prepare.md` is also a SHORT prose document, aimed at the synthetic prepare agent that runs before `implement` on shipped schemas. Without this partial, the prepare agent detects the stack from the tree and guesses at the install command. With it, the agent uses your exact command and your readiness probe. Target ~10–30 lines.

Recommended sections (cover at minimum):

1. **Stack / install command** — the exact one-line install or bootstrap command this repo uses. Match CI where possible (e.g. `pnpm install --frozen-lockfile`, `npm ci`, `uv sync --frozen`, `poetry install --no-interaction`, `bundle install`). Lockfile-respecting flags matter — reproducibility is the whole point.
2. **Readiness probe** — a cheap command the agent can run FIRST to decide whether the environment is already prepared. Typecheck, dry-run build, `pnpm install --frozen-lockfile --dry-run`, `python -c 'import <pkg>'`, `make check-deps`, etc. Must be fast. If the probe passes, the agent skips the install step.
3. **Post-install setup** — any required code-generation, env-file scaffolding, or migration step that must run before the next agent step can do useful work. Only list steps that are BOTH required AND cheap to run every time.
4. **Guardrails** — repo-specific "do not do X" notes. The shipped prepare prompt already forbids editing source files, committing, or running tests; add anything specific to your repo (e.g. "do not run `pnpm build` — it is slow and the implement step runs it").

Frame this list as recommended, not mandatory. A repo with no post-install setup can omit section 3. A repo with no extra guardrails can omit section 4.

### Concrete example (prepare.md)

Adapt the example to what you detected in step 1 (which lockfile is present, etc.).

Example for a TypeScript pnpm monorepo:

```markdown
# Preparing a worktree for this repo

## Install

`pnpm install --frozen-lockfile` — matches CI. Do NOT pass `--no-frozen-lockfile`.

## Readiness probe

`pnpm -r exec node -e 'process.exit(0)'` — succeeds only if every workspace has its deps installed. If it fails, run the install command above, then re-run the probe.

## Post-install

- No code generation required.
- No env-file setup required for the unit suite.

## Do not

- Do not run `pnpm build` here — it is expensive and the implement step handles builds on demand.
- Do not run tests — verification happens inside the implement session, not here.
```

For a Python `uv` project it might be three lines: install command, `uv run python -c 'import <pkg>'` as the readiness probe, nothing else.

---

## 4. Hand off

Summarize:
- whether the user still needs to author `contractor/partials/testing.md` (or edit an existing short one)
- whether the user still needs to author `contractor/partials/prepare.md`
- exactly where each goes (`contractor/partials/testing.md` and `contractor/partials/prepare.md`)
- if a legacy `contractor/VERIFY.md` was found, remind them to move it to `contractor/partials/testing.md`
- if a legacy `verify:` field was found in `contractor/config.yaml`, remind them to remove that line
- a one-line reminder that `/contractor:doctor` (or `contractor doctor`) reports each partial's presence under "Partials wiring"

Then stop. The user writes the files. You do not.

---

## Guardrails

- **Read-only session** — You MUST NOT write, modify, or delete any file. Probing and recommending only. This applies to both `contractor/partials/testing.md` and `contractor/partials/prepare.md`.
- **Teach, don't author** — Show examples, explain structure, but the user writes both partials themselves. Research shows agent-authored context files decrease success rates; human authorship is the whole point.
- **Brevity** — Push the user toward short partials. A bloated one is worse than a missing one, and every line is inlined into every relevant agent prompt.
- **Match CI** — Recommend the same commands CI uses (default test command for `testing.md`, lockfile-respecting install for `prepare.md`). Drift between local and CI is a common failure mode.
- **Two partials, one convention** — Both live under `contractor/partials/` with the id-as-filename convention. Do NOT teach, mention, or recommend a `verify:` field in `contractor/config.yaml` (removed), `worktree.bootstrap` in `contractor/config.yaml` (removed), or a repo-root `VERIFY.md`/`PREPARE.md` (never supported). If the user asks about any of these, explain the partials directory replaces them.
- **Don't lecture** — If the user already has a solid `testing.md` and `prepare.md`, skip past the teaching sections and just confirm the wiring.
