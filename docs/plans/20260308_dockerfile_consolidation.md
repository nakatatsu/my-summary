# Plan: Dockerfile統合 + CI/CDイメージ分離

## Context

`.devcontainer/` 配下に4つのDockerfileがあるが:
1. `local` 以外の3つ（backend, frontend, infrastructure）はCI/CD専用でありdevcontainerではない
2. baseステージ（~44行）が4ファイルに完全コピペされている
3. バージョン管理が `versions.env` → `devcontainer.json` build args の手動二重管理になっている

Dockerのマルチターゲットビルドで**1つのDockerfileに統合**し、バージョンも ARG デフォルト値に一本化する。

## 方針

- **4つのDockerfileを `docker/Dockerfile` 1ファイルに統合**（マルチターゲット）
- **`versions.env` を廃止**し、Dockerfile の `ARG` デフォルト値を single source of truth にする
- **`.devcontainer/` には `devcontainer.json` のみ**配置（scripts も `docker/` に移動）
- ビルドコンテキストは `docker/`（全リソースがここに集約）
- `devcontainer.json` は `"context": "../docker"` で参照

## 変更後のディレクトリ構成

```
docker/                           # ビルドリソース一式
  Dockerfile                      # 統合（base → infrastructure, backend, frontend, local）
  scripts/
    init-firewall.sh              # 移動元: .devcontainer/scripts/（実行時に使用）
    test-install.sh               # 移動元: .devcontainer/scripts/
  build.sh                        # 移動元: .devcontainer/scripts/build-local.sh（簡略化）
  README.md                       # 新規

.devcontainer/
  devcontainer.json               # これだけ
```

**削除対象:**
- `.devcontainer/dockerfiles/` — ディレクトリごと削除
- `.devcontainer/scripts/` — `docker/scripts/` に移動後削除
- `.devcontainer/versions.env` — Dockerfile ARG に統合後削除
- `.devcontainer/README.md` — `docker/README.md` に統合

## docker/Dockerfile の構造

```dockerfile
# Multi-target Dockerfile
# Build context: docker/
# Usage: docker build --target <target> docker/

# ============================================================
# Base (shared across all targets)
# ============================================================
ARG NODE_VERSION=24.13
FROM node:${NODE_VERSION} AS base

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Versions (single source of truth)
ARG CLAUDE_CODE_VERSION=2.1.50
ARG AWS_CLI_VERSION=2.33
ARG GIT_DELTA_VERSION=0.18.2
ARG ZSH_IN_DOCKER_VERSION=1.2.1
ARG TZ=UTC

ENV TZ="$TZ" \
    DEVCONTAINER=true \
    NPM_CONFIG_PREFIX=/usr/local/share/npm-global \
    PATH=$PATH:/usr/local/share/npm-global/bin \
    SHELL=/bin/zsh \
    EDITOR=vim \
    VISUAL=vim

# install-base.sh の内容を直接記述（スクリプト廃止）
RUN apt-get update && apt-get install -y --no-install-recommends \
  less git procps sudo fzf zsh man-db unzip gnupg2 gh jq nano vim \
  iptables ipset iproute2 dnsutils aggregate curl \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

# AWS CLI
RUN ARCH=$(uname -m) && \
  curl "https://awscli.amazonaws.com/awscli-exe-linux-${ARCH}-${AWS_CLI_VERSION}.0.zip" -o awscliv2.zip && \
  unzip awscliv2.zip && ./aws/install && rm -rf aws awscliv2.zip

# User/workspace setup
RUN mkdir -p /usr/local/share/npm-global && chown -R node:node /usr/local/share && \
  mkdir /commandhistory && touch /commandhistory/.bash_history && chown -R node /commandhistory && \
  mkdir -p /workspace /home/node/.claude && chown -R node:node /workspace /home/node/.claude

# git-delta
RUN ARCH=$(dpkg --print-architecture) && \
  wget "https://github.com/dandavison/delta/releases/download/${GIT_DELTA_VERSION}/git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb" && \
  dpkg -i "git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb" && rm "git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb"

# ... zsh, claude code, firewall（現在のbase stageと同内容）

# ============================================================
# Infrastructure target
# ============================================================
FROM base AS infrastructure
ARG TERRAFORM_VERSION=1.14
ARG TFLINT_VERSION=0.61
ARG CHECKOV_VERSION=3.2
ARG TERRAFORM_DOCS_VERSION=0.21
# ... install commands

# ============================================================
# Backend target
# ============================================================
FROM base AS backend
ARG GO_VERSION=1.26
ARG GOFUMPT_VERSION=0.9
ARG GOIMPORTS_VERSION=0.42
ARG GOLANGCI_LINT_VERSION=2.9
ARG GOVULNCHECK_VERSION=1.1
ARG OSV_SCANNER_VERSION=2.3
ARG GOSEC_VERSION=2.23
# ... install commands

# ============================================================
# Frontend target
# ============================================================
FROM base AS frontend
ARG NEXTJS_VERSION=16.1
# ... install commands

# ============================================================
# Local Development target (all tools)
# ============================================================
FROM base AS local
# 全ARG再宣言 + 全ツールインストール
# 各セクションにコメントで対応ターゲットを明記
```

## versions.env 廃止による影響と対応

### なぜ廃止できるか

| 現在の利用箇所 | ARG デフォルト統合後 |
|---|---|
| `devcontainer.json` build args（19個の手動同期） | **削除**。ARG デフォルトが使われる |
| GitHub Actions の Load versions ステップ | **削除**。build-args 指定なしでデフォルトが使われる |
| `build-local.sh` のバージョンパース | **削除**。`docker build` するだけ |

**バージョンを変更したい時**: `docker/Dockerfile` の ARG デフォルト値を変更するだけ。1箇所。

**一時的にバージョンを上書きしたい時**: `--build-arg GO_VERSION=1.27` で上書き可能（ARGの仕様）。

## GHCRイメージ名の変更

| 変更前 | 変更後 |
|--------|--------|
| `ghcr.io/nakatatsu/devcontainer-backend` | `ghcr.io/nakatatsu/ci-backend` |
| `ghcr.io/nakatatsu/devcontainer-frontend` | `ghcr.io/nakatatsu/ci-frontend` |
| `ghcr.io/nakatatsu/devcontainer-infrastructure` | `ghcr.io/nakatatsu/ci-infrastructure` |
| `ghcr.io/nakatatsu/devcontainer-local` | `ghcr.io/nakatatsu/devcontainer-local`（変更なし） |

## EDITOR/VISUAL の変更

全ターゲット共通で `EDITOR=vim`, `VISUAL=vim` に変更（現在は `nano`）。
`install-base.sh` で vim は既にインストール済み。

## 変更対象ファイル一覧

### 1. `docker/Dockerfile`（新規作成）

4つのDockerfileを1ファイルに統合。全バージョンを ARG デフォルト値として定義。

### 2. `docker/scripts/`（移動）

- `.devcontainer/scripts/init-firewall.sh` → `docker/scripts/init-firewall.sh`（実行時使用）
- `.devcontainer/scripts/test-install.sh` → `docker/scripts/test-install.sh`
- `.devcontainer/scripts/install-base.sh` → **削除**（内容を Dockerfile base ステージに直接記述）

### 3. `docker/build.sh`（移動 + 簡略化）

元: `.devcontainer/scripts/build-local.sh`

バージョンパース不要になるため大幅簡略化:
```bash
#!/bin/bash
set -euo pipefail
DOCKER_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET="${1:-local}"

case "$TARGET" in
  infrastructure|backend|frontend)
    IMAGE_NAME="ci-${TARGET}:local" ;;
  local)
    IMAGE_NAME="devcontainer-local:local" ;;
  *)
    echo "Usage: $0 [infrastructure|backend|frontend|local]"; exit 1 ;;
esac

docker build --target "$TARGET" -t "$IMAGE_NAME" "$DOCKER_DIR"
```

### 4. `docker/README.md`（新規）

ターゲット一覧、ビルドコマンド例、バージョン管理の説明。

### 5. `.devcontainer/devcontainer.json`

```jsonc
{
  "build": {
    "context": "../docker",
    "dockerfile": "Dockerfile",
    "target": "local"
    // build args 全削除
  },
  "containerEnv": {
    "TZ": "${localEnv:TZ:UTC}"
    // NODE_OPTIONS, CLAUDE_CONFIG_DIR, POWERLEVEL9K_DISABLE_GITSTATUS
    // → Dockerfile ENV に移動（静的値なのでビルド時に焼く）
  },
  // remoteEnv 等は変更なし
}
```

Dockerfile の base ステージに追加する ENV:
```dockerfile
ENV NODE_OPTIONS="--max-old-space-size=4096" \
    CLAUDE_CONFIG_DIR="/home/node/.claude" \
    POWERLEVEL9K_DISABLE_GITSTATUS="true"
```

TZ だけは `${localEnv:TZ:UTC}` でユーザーのローカルタイムゾーンを動的に取得するため containerEnv に残す。

### 6. `.github/workflows/devcontainer-build-images.yml`

**Load versions ステップを削除。**

**matrix を `include` 形式に:**
```yaml
matrix:
  include:
    - target: infrastructure
      image: ci-infrastructure
    - target: backend
      image: ci-backend
    - target: frontend
      image: ci-frontend
    - target: local
      image: devcontainer-local
```

**build step:**
```yaml
- name: Build and push
  uses: docker/build-push-action@v6
  with:
    context: docker
    file: docker/Dockerfile
    target: ${{ matrix.target }}
    push: true
    tags: |
      ${{ env.REGISTRY }}/${{ env.OWNER }}/${{ matrix.image }}:latest
      ${{ env.REGISTRY }}/${{ env.OWNER }}/${{ matrix.image }}:${{ steps.date.outputs.build_date }}
    cache-from: type=registry,ref=${{ env.REGISTRY }}/${{ env.OWNER }}/${{ matrix.image }}:latest
    cache-to: type=inline
    # build-args 不要（ARGデフォルトを使用）
```

**paths トリガー:**
```yaml
paths:
  - 'docker/**'
  - '.devcontainer/devcontainer.json'
```

**Trivy の image-ref, SARIF category も `${{ matrix.image }}` に。**

### 7. `.github/workflows/devcontainer-pr-validation.yml`

```yaml
on:
  pull_request:
    paths:
      - 'docker/**'
      - '.devcontainer/devcontainer.json'
      - '.github/workflows/devcontainer-*.yml'

jobs:
  validate:
    steps:
      - name: Validate devcontainer.json
        run: jq empty .devcontainer/devcontainer.json

      - name: Lint Dockerfile
        uses: hadolint/hadolint-action@v3.3.0
        with:
          dockerfile: docker/Dockerfile
          ignore: DL3008,DL3009,DL3015,DL4001,DL3016,DL3059
          failure-threshold: warning
```

### 8. `.github/dependabot.yml`

```yaml
- package-ecosystem: docker
  directory: /docker
  schedule:
    interval: weekly
```

`/.devcontainer/dockerfiles` エントリを `/docker` に変更。

### 9. 削除

- `.devcontainer/dockerfiles/` — ディレクトリごと（git rm -r）
- `.devcontainer/scripts/` — 移動後に削除（git mv）
- `.devcontainer/versions.env` — 廃止（git rm）
- `.devcontainer/README.md` — `docker/README.md` に統合（git rm）

## 変更しないもの

- `docker/scripts/init-firewall.sh` — 内容変更なし（パスのみ変更）
- `docker/scripts/test-install.sh` — 同上
- `.devcontainer/devcontainer.json` の build 以外のセクション — 変更なし

## 検証方法

1. `docker/build.sh backend` でCI/CDイメージがビルドできることを確認
2. `docker/build.sh local` でdevcontainerイメージがビルドできることを確認
3. `jq empty .devcontainer/devcontainer.json` でJSON妥当性確認
4. `hadolint docker/Dockerfile` でlint通過確認
5. GitHub Actionsワークフローの構文検証（actionlint）
