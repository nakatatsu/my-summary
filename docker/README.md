# Docker Images

Multi-target Dockerfile for local development and CI/CD pipelines. Built and published to GHCR via GitHub Actions.

## Targets

| Target           | Image Name            | Use                         |
| ---------------- | --------------------- | --------------------------- |
| `local`          | `devcontainer-local`  | Local development (default) |
| `infrastructure` | `ci-infrastructure`   | CI/CD for Terraform         |
| `backend`        | `ci-backend`          | CI/CD for Go                |
| `frontend`       | `ci-frontend`         | CI/CD for Next.js           |

All targets share a common `base` stage with Node.js, Claude Code, AWS CLI, zsh, and git-delta.

## Build

All commands below assume you are in the repository root.

```bash
# Local development (default)
docker build --target local -t devcontainer-local:test docker/

# Specific target
docker build --target backend -t ci-backend:test docker/
```

## Version Management

All tool versions are defined as `ENV` in the `base` stage of `docker/Dockerfile` (single source of truth). To update a version, edit the `ENV` value directly.

## Testing

PR validation workflow builds all targets and verifies installed tools. No push to GHCR on PR.

## References

- Images: `ghcr.io/nakatatsu/ci-{infrastructure,backend,frontend}`, `ghcr.io/nakatatsu/devcontainer-local`
- DevContainer config: [`.devcontainer/devcontainer.json`](../.devcontainer/devcontainer.json)
