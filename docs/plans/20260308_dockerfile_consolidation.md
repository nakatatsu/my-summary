# Plan: Dockerfile統合 + CI/CDイメージ分離

## Context

`.devcontainer/` 配下に4つのDockerfileがあるが:
1. `local` 以外の3つ（backend, frontend, infrastructure）はCI/CD専用でありdevcontainerではない
2. baseステージ（~44行）が4ファイルに完全コピペされている
3. バージョン管理が `versions.env` → `devcontainer.json` build args の手動二重管理になっている

Dockerのマルチターゲットビルドで**1つのDockerfileに統合**し、バージョンも一本化する。

## 方針

- **4つのDockerfileを `docker/Dockerfile` 1ファイルに統合**（マルチターゲット）
- **`versions.env` を廃止**し、Dockerfile の base ステージの `ENV` を single source of truth にする
- `NODE_VERSION` は `FROM` 行に直書き（`FROM node:24.13`）。`ENV` では `FROM` 行を制御できないため
- `TZ` のみ `ARG`（`devcontainer.json` の `containerEnv` から動的に上書きするため）
- それ以外の全バージョンは `ENV`（`--build-arg` による上書きを防止）
- **`.devcontainer/` には `devcontainer.json` のみ**配置
- ビルドコンテキストは `docker/`（リソースをフラットに配置）
- `devcontainer.json` は `"context": "../docker"` で参照
- テストビルド＋インストール検証は GHA の PR validation で実施（ローカルスクリプト不要）

## 変更後のディレクトリ構成

```
docker/
  Dockerfile              # 統合（base → infrastructure, backend, frontend, local）
  init-firewall.sh        # 移動元: .devcontainer/scripts/（実行時に使用）
  README.md               # 新規

.devcontainer/
  devcontainer.json       # これだけ
```

**削除対象:**
- `.devcontainer/dockerfiles/` — ディレクトリごと削除
- `.devcontainer/scripts/` — `docker/` に移動後削除
- `.devcontainer/versions.env` — Dockerfile ENV に統合後削除
- `.devcontainer/README.md` — `docker/README.md` に統合
- `.devcontainer/scripts/install-base.sh` — Dockerfile base ステージに直接記述
- `.devcontainer/scripts/test-install.sh` — GHA PR validation のステップに移行

## docker/Dockerfile の構造

base ステージに全バージョンを `ENV` で定義し、各ターゲットが継承する。詳細は `docker/Dockerfile` を参照。

## versions.env 廃止による影響と対応

### なぜ廃止できるか

| 現在の利用箇所 | ENV 統合後 |
|---|---|
| `devcontainer.json` build args（19個の手動同期） | **削除**。ENV のデフォルトが使われる |
| GitHub Actions の Load versions ステップ | **削除**。build-args 指定なしでデフォルトが使われる |

**バージョンを変更したい時**: `docker/Dockerfile` の `ENV` を変更するだけ。1箇所。

## GHCRイメージ名の変更

| 変更前 | 変更後 |
|--------|--------|
| `ghcr.io/nakatatsu/devcontainer-backend` | `ghcr.io/nakatatsu/ci-backend` |
| `ghcr.io/nakatatsu/devcontainer-frontend` | `ghcr.io/nakatatsu/ci-frontend` |
| `ghcr.io/nakatatsu/devcontainer-infrastructure` | `ghcr.io/nakatatsu/ci-infrastructure` |
| `ghcr.io/nakatatsu/devcontainer-local` | `ghcr.io/nakatatsu/devcontainer-local`（変更なし） |

## イメージタグ戦略

| タグ | 用途 |
|------|------|
| `latest` | 最新ビルドを指す |
| `<commit SHA>` | 正確なトレーサビリティ |
| `YYYYMMDD-<短縮SHA>` | 人間可読な日付＋一意性（同日上書き防止） |

## EDITOR/VISUAL の変更

全ターゲット共通で `EDITOR=vim`, `VISUAL=vim` に変更（現在は `nano`）。

## 変更対象ファイル一覧

### 1. `docker/Dockerfile`（新規作成）

4つのDockerfileを1ファイルに統合。全バージョンを base ステージの `ENV` として定義。

### 2. `docker/init-firewall.sh`（移動）

`.devcontainer/scripts/init-firewall.sh` から移動。内容変更なし。

### 3. `docker/README.md`（新規）

ターゲット一覧、ビルドコマンド例、バージョン管理の説明。

### 4. `.devcontainer/devcontainer.json`

- `build.context` を `"../docker"` に変更
- `build.target` に `"local"` を追加
- build args 全削除
- `containerEnv` から静的値（`NODE_OPTIONS`, `CLAUDE_CONFIG_DIR`, `POWERLEVEL9K_DISABLE_GITSTATUS`）を削除し Dockerfile の `ENV` に移動
- `TZ` のみ `containerEnv` に残す（`${localEnv:TZ:UTC}` で動的取得）

### 5. `.github/workflows/devcontainer-build-images.yml`

- Load versions ステップを削除
- matrix を `include` 形式に（target + image）
- build context を `docker` に、`target` パラメータ追加
- build-args 全削除（ENV デフォルトを使用）
- 日付タグを `YYYYMMDD-短縮SHA` 形式に変更
- paths トリガーを `docker/**` と `.devcontainer/devcontainer.json` に変更

### 6. `.github/workflows/devcontainer-pr-validation.yml`

- paths トリガーを `docker/**` と `.devcontainer/devcontainer.json` に変更
- hadolint 対象を `docker/Dockerfile` 単一ファイルに
- `build-test` ジョブを追加: 4ターゲットをビルド（push なし）＋ `docker run` でツールインストール検証

### 7. `.github/dependabot.yml`

`/.devcontainer/dockerfiles` エントリを `/docker` に変更。

### 8. 削除

- `.devcontainer/dockerfiles/` — ディレクトリごと（git rm -r）
- `.devcontainer/scripts/` — 移動後に削除（git mv）
- `.devcontainer/versions.env` — 廃止（git rm）
- `.devcontainer/README.md` — `docker/README.md` に統合（git rm）

## 変更しないもの

- `docker/init-firewall.sh` — 内容変更なし（パスのみ変更）
- `.devcontainer/devcontainer.json` の build / containerEnv 以外のセクション — 既存のCodex対応（mounts）を除き変更なし

## 検証方法

1. `docker build --target backend -t ci-backend:test docker/` でCI/CDイメージがビルドできること
2. `docker build --target local -t devcontainer-local:test docker/` でdevcontainerイメージがビルドできること
3. `jq empty .devcontainer/devcontainer.json` でJSON妥当性確認
4. `hadolint docker/Dockerfile` でlint通過確認
5. PR validation workflow（build-test ジョブ）でインストール検証が通ること
