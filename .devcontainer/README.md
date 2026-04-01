# DevContainer

Multi-target Dockerfile for local development and CI/CD pipelines.

## Targets

| Target           | Use                         |
| ---------------- | --------------------------- |
| `local`          | Local development (default) |
| `infrastructure` | CI/CD for Terraform         |
| `backend`        | CI/CD for Go                |
| `frontend`       | CI/CD for Next.js           |

All targets share a common `base` stage with Node.js, Claude Code, AWS CLI, zsh, and git-delta.

## Build

All commands below assume you are in the repository root.

```bash
# Local development (default)
docker build --target local -t devcontainer-local:test .devcontainer/

# Specific target
docker build --target backend -t ci-backend:test .devcontainer/
```

## Version Management

All tool versions are defined as `ENV` in the `base` stage of `.devcontainer/Dockerfile` (single source of truth). To update a version, edit the `ENV` value directly.

## References

- DevContainer config: [`devcontainer.json`](devcontainer.json)
