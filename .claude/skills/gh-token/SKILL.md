---
name: gh-token
description: >
  Retrieve GitHub tokens via the gh-token-sidecar container.
  Use this skill whenever a gh command fails with an auth error (401, 403, "auth required",
  "token expired", "bad credentials", etc.). Also use proactively before any Git operation
  (git push, git pull, git fetch, git clone) or GitHub API operation (gh CLI, GitHub API calls)
  to ensure authentication is configured.
---

# gh-token — Token Retrieval Skill

This workspace uses a sidecar container (`gh-token-sidecar`) that issues GitHub App
installation tokens. Always obtain tokens through this sidecar — never use a PAT.

## How to Get a Token

```bash
TOKEN=$(curl -sf http://gh-token-sidecar/token | jq -r '.token')
echo "$TOKEN" | gh auth login --with-token
gh auth setup-git
```

`gh auth login --with-token` registers the token with the gh CLI, then `gh auth setup-git` configures git to use the gh credential helper. This authenticates `gh` CLI, GitHub API calls, and `git push/pull/fetch`.

## If the Sidecar Is Unresponsive

Check health:

```bash
curl -sf http://gh-token-sidecar/health
```

If no response, the sidecar container is likely stopped. Tell the user:
"gh-token-sidecar is not responding. Please run `docker compose up gh-token-sidecar` to start it."

## Important Notes

- Tokens are freshly issued per request (no caching), so expiry is never a concern — just call the endpoint.
- Authentication requires all three steps in order: (1) retrieve the token from the sidecar, (2) `gh auth login --with-token` to register it with the gh CLI, (3) `gh auth setup-git` to configure git's credential helper. Skipping step 2 causes `gh auth setup-git` and `git push` to fail with "not logged in" or "anonymous write access" errors.
- The `.pem` private key exists only inside the sidecar container and is inaccessible from this container. Do not attempt to find or read it.

## When to Use

1. **Before any Git remote operation** (`git push`, `git pull`, `git fetch`, `git clone`) — always run this skill first to set up authentication
2. A `gh` command fails with an auth error (401, 403, "auth required", "token expired", "bad credentials")
3. Before GitHub API operations in a new shell session
4. When a token may have expired (after a long gap)

On auth error, retrieve a fresh token with this skill first, then retry the command.
