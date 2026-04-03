---
name: worktree-remove
description: >
  Remove a git worktree created by /worktree-setup under .worktrees/.
  Use when the user says "remove worktree", "delete worktree", "clean up worktree",
  or wants to remove a parallel working directory.
---

# worktree-remove — git worktree 削除 Skill

Remove a git worktree previously created under `.worktrees/` by `/worktree-setup`.

## Usage

```
/worktree-remove <dir-name>
```

The `<dir-name>` is the directory name under `.worktrees/` (e.g., `feature-auth`, `bugfix-login-crash`). If omitted, list all existing worktrees under `.worktrees/` and ask the user to pick one.

## Execution Steps

### Step 1: Validate Target

If `<dir-name>` is not provided, list available worktrees:

```bash
ls -1 .worktrees/ 2>/dev/null
```

If `.worktrees/` does not exist or is empty, report: "No worktrees found under `.worktrees/`." and stop.

If provided, verify `.worktrees/<dir-name>` exists:

```bash
test -d .worktrees/<dir-name>
```

If it does not exist, **stop** and report: "Worktree `.worktrees/<dir-name>` not found. Run `/worktree-remove` without arguments to see available worktrees."

### Step 2: Check for Uncommitted Changes

```bash
git -C .worktrees/<dir-name> status --porcelain
```

If the output is non-empty (uncommitted changes exist), **stop** and warn:

```
Worktree .worktrees/<dir-name> has uncommitted changes:
<list of changes>

Commit or discard changes before removing, or confirm you want to proceed anyway.
```

Wait for user confirmation before proceeding.

### Step 3: Remove Worktree

```bash
git worktree remove .worktrees/<dir-name>
```

### Step 4: Optionally Delete the Branch

Before removing the worktree (in Step 3), read the branch name from git's tracking:

```bash
cat .git/worktrees/<dir-name>/HEAD
```

If the HEAD file contains `ref: refs/heads/<branch-name>`, extract `<branch-name>`.

After removal, ask the user if they also want to delete the branch:

```
Worktree removed: .worktrees/<dir-name>

The branch "<branch-name>" may still exist. Delete it too? (yes/no)
```

If yes, delete with:

```bash
git branch -d <branch-name>
```

If the branch has unmerged changes, `git branch -d` will fail. Report the error and suggest `git branch -D` only if the user explicitly confirms.

### Step 5: Report Completion

```
Worktree .worktrees/<dir-name> removed successfully.
```

## Error Handling

- **Directory not found**: Report and list available worktrees (see Step 1)
- **Uncommitted changes**: Warn and require confirmation (see Step 2)
- **Branch deletion fails**: Report unmerged status, do not force-delete without explicit confirmation

## Important Notes

- This skill only removes worktrees under `.worktrees/`. It does NOT touch worktrees managed by Claude Code's built-in `EnterWorktree`/`ExitWorktree` (which use `.claude/worktrees/`).
- Requires Git 2.48+ for `worktree.useRelativePaths` support.
