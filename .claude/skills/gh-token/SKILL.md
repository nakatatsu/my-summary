---
name: gh-token
description: >
  Acquire GitHub tokens via the gh-token-sidecar container.
  Use this skill whenever gh commands fail with auth errors (401, 403, "auth required", "token expired", "bad credentials", etc.).
  Also use proactively before any GitHub-authenticated operation (gh auth, git push/pull/fetch, GitHub API calls) when credentials may be missing or expired.
disable-model-invocation: false
---

# gh-token Skill

This workspace uses a sidecar container (`gh-token-sidecar`) that issues GitHub App installation tokens. Never use a PAT — always obtain tokens through this sidecar.

## Obtain a token

```bash
export GH_TOKEN=$(curl -fsS http://gh-token-sidecar/token | jq -r '.token')
```

The token is valid for `gh` commands and GitHub API calls within the same shell session.

## If the sidecar is unresponsive

Check health:

```bash
curl -fsS http://gh-token-sidecar/health
```

If no response, tell the user: "gh-token-sidecar is not responding. Please run `docker compose up gh-token-sidecar`."

## Important

- Tokens are freshly issued per request (no caching). No need to worry about expiry — just call again.
- Setting `GH_TOKEN` is sufficient for `gh` CLI auth. `gh auth login` is unnecessary.
- The `.pem` private key exists only inside the sidecar container. Never attempt to find or read it.

## When to use

1. `gh` command fails with an auth error (most common case)
2. Starting a new shell session before any GitHub operation
3. Token may have expired (e.g. after a long idle period)

On auth error: re-acquire the token with this skill, then retry the command.
