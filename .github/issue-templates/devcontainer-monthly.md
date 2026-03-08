## 概要

YYYY-MM DevContainerツールバージョン更新。
`docker/Dockerfile` の `ENV` に定義された全ツールバージョンを確認し、最新パッチに更新すること。

---

## 対象ファイル

- `docker/Dockerfile` — base ステージの `ENV` ブロック

---

## 確認対象

### base

- [ ] Node.js（`FROM node:XX.YY`）
- [ ] Claude Code（`CLAUDE_CODE_VERSION`）
- [ ] AWS CLI（`AWS_CLI_VERSION`）
- [ ] git-delta（`GIT_DELTA_VERSION`）
- [ ] zsh-in-docker（`ZSH_IN_DOCKER_VERSION`）

### infrastructure

- [ ] Terraform（`TERRAFORM_VERSION`）
- [ ] tflint（`TFLINT_VERSION`）
- [ ] tflint AWS plugin（`TFLINT_AWS_PLUGIN_VERSION`）
- [ ] checkov（`CHECKOV_VERSION`）
- [ ] terraform-docs（`TERRAFORM_DOCS_VERSION`）

### backend

- [ ] Go（`GO_VERSION`）
- [ ] gofumpt（`GOFUMPT_VERSION`）
- [ ] goimports（`GOIMPORTS_VERSION`）
- [ ] golangci-lint（`GOLANGCI_LINT_VERSION`）
- [ ] govulncheck（`GOVULNCHECK_VERSION`）
- [ ] osv-scanner（`OSV_SCANNER_VERSION`）
- [ ] gosec（`GOSEC_VERSION`）

### frontend

- [ ] Next.js（`NEXTJS_VERSION`）
- [ ] React / React DOM（`REACT_VERSION`）
- [ ] TypeScript（`TYPESCRIPT_VERSION`）
- [ ] ESLint（`ESLINT_VERSION`）
- [ ] Prettier（`PRETTIER_VERSION`）
- [ ] Codex（`CODEX_VERSION`）

---

## ルール

- `ENV` の値がそのままインストールされること。
- バージョンは必ず完全形（X.Y.Z）で記載
- PR validation workflow で全ターゲットのビルド＋ツール検証が通ることを確認
