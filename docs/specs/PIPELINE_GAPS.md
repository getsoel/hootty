# Pipeline — Resolved Gaps

All gaps have been resolved. Decisions are recorded here for reference. See [PIPELINE_SPEC.md](./PIPELINE_SPEC.md) for the full spec.

## 1. Stale Claims ✅

**Decision**: PID check + force claim.

- Every `hootty pipeline claim` and `hootty pipeline advance` call checks if existing claims have live PIDs (`kill -0 $pid`). Dead PID → auto-release.
- `hootty pipeline claim --force <job>` lets a user manually override any claim.
- For `$CLAUDE_SESSION_ID` claims (not PID-based), `hootty pipeline reap` as a manual fallback.

## 2. Context Carryover Between Stages ✅

**Decision**: Convention + append to job file.

- Stage commands tell Claude to write output back to the job file under a stage heading (e.g., `## Research`).
- `hootty pipeline claim --format context` reads the full job file including prior stage outputs.
- No special framework — Claude edits the file, the file carries context forward.

## 3. Claiming Semantics ✅

**Decision**: Priority order + error on double claim.

**Claim priority order**:
1. `interrupted` jobs first (already in-flight)
2. First stage with unclaimed `queued` jobs (by filename sort order)
3. Skip jobs claimed by another session

**Double claim**: Error by default ("You already have a claim. Run `hootty pipeline release` first."). One claim per pipeline allowed — so you can claim from `feature` and `bugs` simultaneously.

## 4. Job Creation Flow (UI) ✅

**Decision**: Inline card + incrementing integer.

- Click `[+ Add]` → inline card appears → type title → Enter → card created with stub `.md` file.
- Click card to expand and write the full prompt.
- Auto-numbering: scan all existing files across all stages, take max number + 1.

## 5. Editing Pipeline Structure ✅

**Decision**: CLI commands + board UI context menus.

```
hootty pipeline stage add <name> [--type auto|manual] [--after <stage>]
hootty pipeline stage remove <name>
hootty pipeline stage move <name> --after <stage>
```

Board UI: right-click column header → "Add Stage After", "Remove Stage", "Change Type".

**Rules**: Adding a stage only affects future advancement — existing jobs stay put. Removing a stage moves its jobs to the previous stage (or new first stage if removing the first).

## 6. Backward Movement ✅

**Decision**: Allowed.

`hootty pipeline move` to an earlier stage is a valid operation. Claim stays if present. Status resets to `queued`. Use case: reviewer sends job back for rework.

## 7. Done Stage Accumulation ✅

**Decision**: `hootty pipeline archive` command.

- `hootty pipeline archive [<pipeline>]` moves `done/*.md` to `.hootty/pipeline/<name>/archive/`.
- Archive is git-tracked (useful history).
- Hidden from board UI by default (collapsible "Archive" section).
- Optional: `hootty pipeline archive --before 30d` for age-based archival.

## 8. Empty Claim Output ✅

**Decision**: Non-zero exit + empty context.

- Exit code `1` so scripts/hooks can detect it.
- Human output: `No jobs available to claim in pipeline "feature".`
- `--format context` outputs empty string (hook injects nothing).
- The `|| true` in the session_start hook handles this gracefully.

## 9. Job Logs and History ✅

**Decision**: Append to job file under `## Log`.

Every `hootty pipeline claim`, `hootty pipeline advance`, `hootty pipeline release`, `hootty pipeline move`, and `hootty pipeline log` appends a timestamped entry to the job's `.md` file.

```markdown
## Log

- 2026-03-13 10:00 — Created in Backlog
- 2026-03-13 10:15 — Claimed by sess_a1b2c3
- 2026-03-13 10:15 — Advanced to Implement (automated)
- 2026-03-13 11:30 — Advanced to Review (manual) — claim released
- 2026-03-13 14:00 — Moved back to Implement by user
- 2026-03-13 14:05 — User note: "Needs async/await, not just Promise wrapping"
```

## 10. `hootty pipeline status --format context` Output ✅

**Decision**: Concise board summary, no auto-claim.

```
## Pipelines in this repo

### feature (3 jobs)
- Backlog: 001-auth-refactor, 002-fix-sidebar
- Implement: 003-add-tests (active, claimed)
- Review: (empty)
- Done: 000-setup

### bugs (1 job)
- Triage: 001-crash-on-login (active, claimed)

To pick up a task: `hootty pipeline claim` or `hootty pipeline claim <job-slug>`
```

If no pipelines or no jobs, outputs nothing.

## 11. Session ID Visibility ✅

**Decision**: `hootty pipeline whoami` command.

```
$ hootty pipeline whoami
Session ID: sess_a1b2c3
Source: $CLAUDE_SESSION_ID
Current claim: 001-auth-refactor (feature, stage: Implement)
```

## 12. Prompt Variable Resolution ✅

**Decision**: Fixed resolution order.

1. Built-in: `{{job}}`, `{{stage}}`, `{{pipeline}}`, `{{repo}}`
2. Job frontmatter: `{{title}}`, `{{priority}}`, etc.
3. Pipeline `settings.variables` from `pipeline.yaml`
4. Environment variables: `{{ENV_VAR}}`
5. Unresolved → leave as-is and warn (don't block the agent)

## 13. Deleting Whole Pipelines ✅

**Decision**: `hootty pipeline delete <name>`.

- Removes `.hootty/pipeline/<name>/` directory entirely.
- Requires confirmation (or `--yes` to skip).
- Refuses if there are active claims.
- If deleting the default pipeline, errors and asks user to set a new default first.

## 14. `memory.md` Usage ✅

**Decision**: Injected as preamble in `hootty pipeline claim --format context`.

- Shared project context (conventions, architecture notes, team norms).
- Prepended before the job content in `--format context` output.
- Edited by hand or `hootty pipeline edit memory`.
- Not shown on board cards — it's global, not per-job.
- If `memory.md` doesn't exist or is empty, nothing is prepended.

## 15. Prompt Boundary with Stage Outputs ✅

**Decision**: Original prompt = frontmatter to first `##` heading.

- Stage outputs (`## Research`, `## Spec`), `## Notes`, and `## Log` are accumulated context below the original prompt.
- `hootty pipeline advance` prints the stage command or the original prompt body (not the full file).
- `hootty pipeline claim --format context` injects the **full file** — prompt + all accumulated stage outputs + notes + log. The next session gets complete context.
- This means the file grows over time. That's intentional — it's the job's living document.

## 16. `hootty pipeline add` Body ✅

**Decision**: Stub creation + optional body/editor.

- `hootty pipeline add "title"` — creates stub file with title in frontmatter, empty body.
- `hootty pipeline add "title" --edit` — creates stub, then opens in `$EDITOR`.
- `hootty pipeline add "title" --body "prompt text"` — creates file with the given body. For scripting.
- `hootty pipeline edit <job>` — opens any existing job in `$EDITOR` to fill in or modify the body later.

## 17. Board Scope in Multi-Repo ✅

**Decision**: Shows pipelines from the focused pane's repo.

- Board header shows a repo indicator (repo name + path) so the user knows which repo's pipelines are displayed.
- If panes span multiple repos with pipelines, a repo picker dropdown in the board header lets the user switch.
- If the focused pane has no repo or no `.hootty/pipeline/`, board shows an empty state with setup instructions (`hootty pipeline init`).
- Switching between Terminals and Pipelines views preserves the selected repo.

## 18. Concurrent `.state.json` Writes ✅

**Decision**: File lock (Phase 1) + daemon serialization (Phase 2+).

- **Phase 1 (no daemon)**: Advisory file lock (`flock`) on `.state.json` during every read-modify-write cycle. Simple, works on macOS/Linux. Short hold time (microseconds).
- **Phase 2+ (daemon running)**: Daemon is the sole writer. CLI sends commands over socket, daemon serializes all writes. No race conditions possible.
- Resolves former open question #3.

## 19. `hootty pipeline advance` Without a Claim ✅

**Decision**: Error with clear message.

- Output: `No active claim. Run \`hootty pipeline claim\` first.`
- Exit code: `1`
- Same pattern for `hootty pipeline release` without a claim.

## 20. Spec Bugs (Audit Round 2) ✅

**Socket path conflict**: Was `~/.pipeline/pipeline.sock` in one place, `.hootty/pipeline/pipeline.sock` in another. **Decision**: Repo-local `.hootty/pipeline/pipeline.sock`. One daemon per repo.

**`hootty pipeline claim` argument ambiguity**: `hootty pipeline claim feature` — is it a pipeline name or a job slug? **Decision**: Positional argument is always a pipeline name. Use `--job <slug>` for specific jobs. Unambiguous.

**`hootty pipeline claim --stage` undocumented**: Was shown in narrative but missing from CLI reference. **Decision**: Added to CLI reference.

**`hootty pipeline current-job` missing from reference**: Listed in examples but not in CLI commands. **Decision**: Added to CLI reference.

## 21. Slug Derivation & Auto-Numbering ✅

**Decision**: Title lowercased, non-alphanumeric → hyphens, consecutive hyphens collapsed, max 50 chars. Zero-padded 3-digit prefix (`001`). `flock` scope extended to cover `hootty pipeline add` (not just `.state.json` reads). Numeric-aware sort on prefix.

## 22. Stage Directory Lifecycle ✅

**Decision**: Auto-created by CLI when missing. Orphan directories (not in `pipeline.yaml`) are ignored. "Done" is not special — just the last stage in the list.

## 23. Remove / Delete Guards ✅

**Decision**: `hootty pipeline remove` on a claimed job releases the claim first. `hootty pipeline stage remove` with claimed jobs preserves claims, moves jobs to previous stage.

## 24. Double Advance Prevention ✅

**Decision**: `hootty pipeline advance` checks the job is still in the expected stage. If moved by another process, errors: "Job has moved since your last action."

## 25. Fresh Clone State ✅

**Decision**: CLI creates `.state.json` on first invocation if missing. All jobs default to `queued`. No claims. Not paused.

## 26. Play/Pause Without Daemon ✅

**Decision**: `paused` flag written to `.state.json`. Both `hootty pipeline claim` and `hootty pipeline advance` check it and error if paused.

## 27. Known Limitations (Deferred) ✅

Documented in spec under "Known Limitations": corrupt file recovery, git merge conflicts, file size limits, PID recycling, multiple daemons, custom template saving.
