# Docker Images

Dockerfile for local development environment. Built locally via docker-compose.

## Build

All commands below assume you are in the repository root.

```bash
docker build --target local -t devcontainer-local:test docker/
```

## Version Management

All tool versions are defined as `ENV` in the `base` stage of `docker/Dockerfile` (single source of truth). To update a version, edit the `ENV` value directly.

## Testing

PR validation workflow builds the image and verifies installed tools.

## References

- DevContainer config: [`.devcontainer/devcontainer.json`](../.devcontainer/devcontainer.json)
