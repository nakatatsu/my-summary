#!/bin/bash
# Install Claude Code plugins defined in .claude/settings.json enabledPlugins
set -e

PLUGINS=(
  "frontend-design@claude-plugins-official"
  "context7@claude-plugins-official"
  "code-review@claude-plugins-official"
  "superpowers@claude-plugins-official"
  "github@claude-plugins-official"
  "code-simplifier@claude-plugins-official"
  "typescript-lsp@claude-plugins-official"
  "playwright@claude-plugins-official"
  "commit-commands@claude-plugins-official"
  "security-guidance@claude-plugins-official"
  "pr-review-toolkit@claude-plugins-official"
  "slack@claude-plugins-official"
  "gopls-lsp@claude-plugins-official"
  "stripe@claude-plugins-official"
  "skill-creator@claude-plugins-official"
)

for plugin in "${PLUGINS[@]}"; do
  echo "Installing plugin: ${plugin}"
  claude plugin install "${plugin}" --scope project || echo "Warning: Failed to install ${plugin}"
done

echo "Plugin installation complete."
