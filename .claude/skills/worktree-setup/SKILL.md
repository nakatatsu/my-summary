---
name: worktree-setup
description: >
  Create a git worktree under .worktrees/ with automatic prerequisite setup
  (.gitignore entry).
  Use when the user says "worktree-setup", "create worktree", "add worktree",
  or wants to set up a parallel working directory for a branch.
  Do NOT confuse with the built-in EnterWorktree tool which uses .claude/worktrees/.
---

# worktree-setup — git worktree セットアップ Skill

Create a git worktree under `.worktrees/` at the repository root with all prerequisites automatically configured.

## Usage

```
/worktree-setup <branch-name>
```

The `<branch-name>` argument is required. The skill automatically detects whether the branch already exists (locally or on remote) and uses the appropriate git command.

## Execution Steps

### Step 1: Ensure `.worktrees/` is in `.gitignore`

```bash
grep -qxF '.worktrees/' .gitignore 2>/dev/null || echo '.worktrees/' >> .gitignore
```

> `worktree.useRelativePaths` is configured globally via `postStartCommand` in `devcontainer.json`.

### Step 2: Determine Directory Name

Derive the worktree directory name from `<branch-name>` by replacing all `/` with `-`.

Examples:
- `feature/auth` → `.worktrees/feature-auth`
- `bugfix/login-crash` → `.worktrees/bugfix-login-crash`
- `my-branch` → `.worktrees/my-branch`

Store the derived directory name as `<dir>`.

### Step 3: Check for Existing Worktree

Before creating, verify that `.worktrees/<dir>` does not already exist:

```bash
test -d .worktrees/<dir>
```

If it exists, **stop** and report: "Worktree `.worktrees/<dir>` already exists. Remove it first or choose a different branch name."

### Step 4: Detect Branch Type and Create Worktree

Fetch latest refs, then check if the branch exists locally or on remote:

```bash
git fetch origin
git rev-parse --verify <branch-name> >/dev/null 2>&1 || git rev-parse --verify origin/<branch-name> >/dev/null 2>&1
```

**If the branch exists** (exit code 0 from either check):

```bash
git worktree add .worktrees/<dir> <branch-name>
```

**If the branch does NOT exist** (new branch):

```bash
git worktree add -b <branch-name> .worktrees/<dir> origin/main
```

### Step 5: Verify Worktree

```bash
git -C .worktrees/<dir> status
```

Exit code 0 means the worktree is functional.

### Step 6: Report Completion

After successful creation, display:

```
Worktree created: .worktrees/<dir> (branch: <branch-name>)

Next steps:
  cd .worktrees/<dir>
  claude
```

## Error Handling

- **`<branch-name>` not provided**: Stop and display usage: `/worktree-setup <branch-name>`
- **Worktree directory already exists**: Stop with message (see Step 3)
- **`git worktree add` fails**: Report the git error output to the user. Common causes: uncommitted changes on the branch, branch already checked out in another worktree.

## Worktree Deletion

To remove a worktree, use `/worktree-remove <dir-name>`. See the `worktree-remove` skill for details.

## Important Notes

- This skill creates worktrees under `.worktrees/` at the repository root. Do NOT confuse with Claude Code's built-in `EnterWorktree` tool which uses `.claude/worktrees/`.
- Requires Git 2.48+ for `worktree.useRelativePaths` support.
