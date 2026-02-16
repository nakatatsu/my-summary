# DevContainer

Multi-stage Docker builds for local development and CI/CD. Windows (WSL2) and Linux tested.

## Quick Start

```bash
code .
# Command Palette → "Dev Containers: Reopen in Container"
```

**Prerequisites**: Docker Desktop/Engine, VS Code, Dev Containers extension

## Images

| Image | Use |
|-------|-----|
| `local` | Local development (default) |
| `infrastructure` | CI/CD for Terraform |
| `backend` | CI/CD for Go |
| `frontend` | CI/CD for Next.js |

Multi-stage builds. No external base image.

## Local Build

```bash
./scripts/build-local.sh [infrastructure|backend|frontend|local]
```

## Key Files

- `versions.env` - Tool versions (X.Y pinned)
- `dockerfiles/` - 4 Dockerfiles
- `scripts/init-firewall.sh` - Network allowlist

## References

- Images: `ghcr.io/nakatatsu/devcontainer-*`
- Base: [anthropics/claude-code](https://github.com/anthropics/claude-code)
