---
name: close
description: Close a completed change: sync with main, merge, record completion in the DB,
---

0. **Worktree check**: `blueprint:*` commands run inside a blueprint worktree. Verify `contractor/` exists in CWD and you are on a `contractor/<name>` branch rather than the blueprint's base branch (the branch you started from):
   ```
   test -d contractor && git rev-parse --abbrev-ref HEAD
   ```
   If `contractor/` is missing or HEAD is still on the base branch, refuse with: "`blueprint:*` commands must run from inside a worktree. `cd` into `contractor/.worktrees/<name>/` first, or run `/contractor:propose` to create a new blueprint."

1. **Detect active blueprint**:
   ```
   contractor blueprint show --json
   ```
   A worktree should have exactly one active blueprint (the one matching its branch). If none is found, report the error to the user and stop — do not fall back to `blueprint list`.


Close a completed change: sync with main, merge, record completion in the DB,
delete the blueprint directory, and clean up the worktree.

Steps:
1. Capture the blueprint's base branch into `$BASE`:
   `BASE=$(contractor blueprint base <name>)`
   Every subsequent `$BASE` reference uses this value; if the blueprint has no
   recorded base, the subcommand falls back to the repo's default branch.
2. Verify completion with `contractor blueprint status --blueprint <name>`
3. Commit any uncommitted work
4. Record branch name and worktree path
5. Sync the worktree with the base branch:
   a. `git fetch origin && git merge origin/$BASE` (or `git merge $BASE` for local-only repos)
   b. If conflicts occur, resolve each conflicted file in a single pass
   c. Verify the resolution by running the project's build and test commands
      (inspect repo conventions — README, package.json, Makefile, etc. — to find the right commands)
   d. If resolution or verification fails, run `git merge --abort`
      (or `git reset --hard ORIG_HEAD` if the merge was already committed) and stop
6. Switch to the main repo root and squash merge:
   a. Record the main repo root while still in the worktree:
      `MAIN_REPO=$(dirname "$(git rev-parse --path-format=absolute --git-common-dir)")`
   b. `cd "$MAIN_REPO"` — every remaining step runs from the main repo root, NOT the worktree.
      The worktree will be removed in step 10; if CWD is still inside it, the shell ends up
      in a non-existent directory and every subsequent command fails sandbox CWD validation
      (prefixing `cd` does not help — the check runs before the command).
   c. `git checkout "$BASE"`
   d. `git merge --squash contractor/<name>`
   e. Craft a single Conventional Commits message summarizing the blueprint's changes.
      Use the blueprint's proposal title/description and delta specs to write a clear
      subject line (under 72 chars) and body. Example: `feat: add pipeline resume support`
   f. `git commit` with the crafted message (do NOT use `--no-verify`)
7. Close: `contractor blueprint close <name> --yes`
   (this applies delta specs, records completion in the DB, and deletes the blueprint directory)
8. Check for capability overlap with remaining active blueprints:
   a. Run `contractor blueprint graph --json` to compute the overlap matrix
   b. If any remaining active blueprints share capabilities with the closing blueprint,
      print a warning listing each overlapping blueprint and its shared capabilities
   c. Suggest running `contractor run --pipeline rebase` on affected blueprints
   d. This warning is advisory only — it does NOT block the close
9. Commit the deletion: `git add -A && git commit -m "chore: close <name>"`
10. Remove worktree: `git worktree remove contractor/.worktrees/<name>/`
11. Delete branch: `git branch -d contractor/<name>`

Important:
- All steps must happen in order — sync before merge, merge before close, close before cleanup
- If conflict resolution fails or verification fails, run `git merge --abort` (or `git reset --hard ORIG_HEAD`) and stop — do not retry
- Steps 6–11 run from the main repo root, not from inside the worktree. Never run `git worktree remove` while CWD is inside the worktree being removed.
- The worktree MUST be removed after a successful close
