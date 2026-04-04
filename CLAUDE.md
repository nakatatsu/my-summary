# CLAUDE.md

This repository focuses on the development system for AI-driven development. It contains development documents and sample code.

## Important

- Check the `CLAUDE.md` file in each working directory.
- Feel free to use `[Repository Root]/.tmp/*` for experiments, testing, and any temporary work.
- Never work directly on the `main` branch. Of course, never commit to `main`.
- Never skip any steps in the user’s instructions.
- Never edit file except users accept.
- Always save `.claude/` files (skills, settings, etc.) in the repository (`/workspace/.claude/`), never in `~/.claude/`.

### Key Skills (always invoke when conditions match)

- `/gh-token` — GitHub token retrieval via sidecar. Use before any Git remote operation or on auth errors using `gh`.
