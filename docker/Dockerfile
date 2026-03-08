# Multi-target Dockerfile
# Build context: docker/
# Usage: docker build --target <target> docker/

# ============================================================
# Base (shared across all targets)
# ============================================================
FROM node:24.13 AS base

SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Versions (single source of truth — all targets inherit these via ENV)
ARG TZ=UTC

ENV TZ="$TZ" \
    DEVCONTAINER=true \
    NPM_CONFIG_PREFIX=/usr/local/share/npm-global \
    PATH=$PATH:/usr/local/share/npm-global/bin \
    SHELL=/bin/zsh \
    EDITOR=vim \
    VISUAL=vim \
    NODE_OPTIONS="--max-old-space-size=4096" \
    CLAUDE_CONFIG_DIR="/home/node/.claude" \
    POWERLEVEL9K_DISABLE_GITSTATUS="true" \
    CLAUDE_CODE_VERSION=2.1.50 \
    AWS_CLI_VERSION=2.33.31 \
    GIT_DELTA_VERSION=0.18.2 \
    ZSH_IN_DOCKER_VERSION=1.2.1 \
    TERRAFORM_VERSION=1.14.6 \
    TFLINT_VERSION=0.61.0 \
    CHECKOV_VERSION=3.2.507 \
    TERRAFORM_DOCS_VERSION=0.21.0 \
    TFLINT_AWS_PLUGIN_VERSION=0.45.0 \
    GO_VERSION=1.26.1 \
    GOFUMPT_VERSION=0.9.2 \
    GOIMPORTS_VERSION=0.42.0 \
    GOLANGCI_LINT_VERSION=2.9.0 \
    GOVULNCHECK_VERSION=1.1.4 \
    OSV_SCANNER_VERSION=2.3.3 \
    GOSEC_VERSION=2.23.0 \
    REACT_VERSION=19.2.4 \
    TYPESCRIPT_VERSION=5.9.3 \
    ESLINT_VERSION=10.0.3 \
    PRETTIER_VERSION=3.8.1 \
    NEXTJS_VERSION=16.1.6 \
    CODEX_VERSION=0.106.0

# System packages
RUN apt-get update && apt-get install -y --no-install-recommends \
  less git procps sudo fzf zsh man-db unzip gnupg2 gh jq nano vim \
  iptables ipset iproute2 dnsutils aggregate curl locales \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

# AWS CLI
RUN ARCH=$(uname -m) && \
  if [ "$ARCH" = "x86_64" ]; then \
    curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64-${AWS_CLI_VERSION}.zip" -o "awscliv2.zip"; \
  elif [ "$ARCH" = "aarch64" ]; then \
    curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64-${AWS_CLI_VERSION}.zip" -o "awscliv2.zip"; \
  fi && \
  unzip awscliv2.zip && ./aws/install && rm -rf aws awscliv2.zip

# User/workspace setup
RUN mkdir -p /usr/local/share/npm-global && chown -R node:node /usr/local/share && \
  mkdir /commandhistory && touch /commandhistory/.bash_history && chown -R node /commandhistory && \
  mkdir -p /workspace /home/node/.claude && chown -R node:node /workspace /home/node/.claude

# git-delta
RUN ARCH=$(dpkg --print-architecture) && \
  wget "https://github.com/dandavison/delta/releases/download/${GIT_DELTA_VERSION}/git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb" && \
  dpkg -i "git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb" && rm "git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb"

# Locale
RUN sed -i 's/^# *\(en_US.UTF-8 UTF-8\)/\1/' /etc/locale.gen && locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8 \
    LC_ALL=en_US.UTF-8

USER node

# zsh
RUN sh -c "$(wget -qO- https://github.com/deluan/zsh-in-docker/releases/download/v${ZSH_IN_DOCKER_VERSION}/zsh-in-docker.sh)" -- \
  -p git -p fzf \
  -a "source /usr/share/doc/fzf/examples/key-bindings.zsh" \
  -a "source /usr/share/doc/fzf/examples/completion.zsh" \
  -a "export PROMPT_COMMAND='history -a' && export HISTFILE=/commandhistory/.bash_history" \
  -a "alias yolo='claude --dangerously-skip-permissions'" \
  -x

# Claude Code
RUN curl -fsSL https://claude.ai/install.sh | bash -s ${CLAUDE_CODE_VERSION}
ENV DISABLE_AUTOUPDATER=1

# Firewall
COPY init-firewall.sh /usr/local/bin/
USER root
RUN chmod +x /usr/local/bin/init-firewall.sh && \
  echo "node ALL=(root) NOPASSWD: /usr/local/bin/init-firewall.sh" > /etc/sudoers.d/node-firewall && \
  chmod 0440 /etc/sudoers.d/node-firewall
USER node

ENV PATH="/home/node/.local/bin:${PATH}"

# ============================================================
# Infrastructure target
# ============================================================
FROM base AS infrastructure

USER root

# Terraform
RUN ARCH="$(dpkg --print-architecture)" && \
  wget -q "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_${ARCH}.zip" && \
  unzip "terraform_${TERRAFORM_VERSION}_linux_${ARCH}.zip" && \
  mv terraform /usr/local/bin/ && rm "terraform_${TERRAFORM_VERSION}_linux_${ARCH}.zip" && \
  chmod +x /usr/local/bin/terraform

# tflint
RUN ARCH="$(dpkg --print-architecture)" && \
  wget -q "https://github.com/terraform-linters/tflint/releases/download/v${TFLINT_VERSION}/tflint_linux_${ARCH}.zip" && \
  unzip "tflint_linux_${ARCH}.zip" && mv tflint /usr/local/bin/ && \
  rm "tflint_linux_${ARCH}.zip" && chmod +x /usr/local/bin/tflint

# checkov
RUN apt-get update && apt-get install -y --no-install-recommends python3 python3-pip python3-venv \
  && apt-get clean && rm -rf /var/lib/apt/lists/* && \
  pip3 install --no-cache-dir checkov==${CHECKOV_VERSION} --break-system-packages

# terraform-docs
RUN ARCH="$(dpkg --print-architecture)" && \
  wget -q "https://github.com/terraform-docs/terraform-docs/releases/download/v${TERRAFORM_DOCS_VERSION}/terraform-docs-v${TERRAFORM_DOCS_VERSION}-linux-${ARCH}.tar.gz" && \
  tar -xzf "terraform-docs-v${TERRAFORM_DOCS_VERSION}-linux-${ARCH}.tar.gz" && \
  mv terraform-docs /usr/local/bin/ && rm "terraform-docs-v${TERRAFORM_DOCS_VERSION}-linux-${ARCH}.tar.gz" && \
  chmod +x /usr/local/bin/terraform-docs

USER node
WORKDIR /workspace

LABEL org.opencontainers.image.source="https://github.com/nakatatsu/mynote"
LABEL org.opencontainers.image.description="Infrastructure CI/CD Image"
LABEL maintainer="nakatatsu"

# ============================================================
# Backend target
# ============================================================
FROM base AS backend

USER root

# Go
RUN ARCH=$(dpkg --print-architecture) && \
  wget -q "https://go.dev/dl/go${GO_VERSION}.linux-${ARCH}.tar.gz" && \
  tar -C /usr/local -xzf "go${GO_VERSION}.linux-${ARCH}.tar.gz" && \
  rm "go${GO_VERSION}.linux-${ARCH}.tar.gz"

ENV PATH=$PATH:/usr/local/go/bin
ENV GOPATH=/home/node/go
ENV PATH=$PATH:/home/node/go/bin

RUN mkdir -p /home/node/go/bin && chown -R node:node /home/node/go

USER node

RUN go install mvdan.cc/gofumpt@v${GOFUMPT_VERSION}
RUN go install golang.org/x/tools/cmd/goimports@v${GOIMPORTS_VERSION}
RUN go install github.com/golangci/golangci-lint/v2/cmd/golangci-lint@v${GOLANGCI_LINT_VERSION}
RUN go install golang.org/x/vuln/cmd/govulncheck@v${GOVULNCHECK_VERSION}
RUN go install github.com/securego/gosec/v2/cmd/gosec@v${GOSEC_VERSION}

USER root

# osv-scanner
RUN ARCH=$(dpkg --print-architecture) && \
  wget -q "https://github.com/google/osv-scanner/releases/download/v${OSV_SCANNER_VERSION}/osv-scanner_linux_${ARCH}" -O /usr/local/bin/osv-scanner && \
  chmod +x /usr/local/bin/osv-scanner

USER node
WORKDIR /workspace

LABEL org.opencontainers.image.source="https://github.com/nakatatsu/mynote"
LABEL org.opencontainers.image.description="Backend CI/CD Image"
LABEL maintainer="nakatatsu"

# ============================================================
# Frontend target
# ============================================================
FROM base AS frontend

USER node

RUN npm install -g next@${NEXTJS_VERSION} react@${REACT_VERSION} react-dom@${REACT_VERSION}
RUN npm install -g typescript@${TYPESCRIPT_VERSION} eslint@${ESLINT_VERSION} prettier@${PRETTIER_VERSION}

WORKDIR /workspace

LABEL org.opencontainers.image.source="https://github.com/nakatatsu/mynote"
LABEL org.opencontainers.image.description="Frontend CI/CD Image"
LABEL maintainer="nakatatsu"

# ============================================================
# Local Development target (all tools)
# ============================================================
FROM base AS local

USER root

# --- Infrastructure tools ---

# Terraform
RUN ARCH="$(dpkg --print-architecture)" && \
  wget -q "https://releases.hashicorp.com/terraform/${TERRAFORM_VERSION}/terraform_${TERRAFORM_VERSION}_linux_${ARCH}.zip" && \
  unzip "terraform_${TERRAFORM_VERSION}_linux_${ARCH}.zip" && \
  mv terraform /usr/local/bin/ && rm "terraform_${TERRAFORM_VERSION}_linux_${ARCH}.zip" && \
  chmod +x /usr/local/bin/terraform

# tflint
RUN ARCH="$(dpkg --print-architecture)" && \
  wget -q "https://github.com/terraform-linters/tflint/releases/download/v${TFLINT_VERSION}/tflint_linux_${ARCH}.zip" && \
  unzip "tflint_linux_${ARCH}.zip" && mv tflint /usr/local/bin/ && \
  rm "tflint_linux_${ARCH}.zip" && chmod +x /usr/local/bin/tflint

# tflint AWS plugin
USER node
RUN printf 'plugin "aws" {\n  enabled = true\n  version = "%s"\n  source  = "github.com/terraform-linters/tflint-ruleset-aws"\n}\n' "${TFLINT_AWS_PLUGIN_VERSION}" > /tmp/.tflint.hcl && \
  tflint --config /tmp/.tflint.hcl --init && \
  rm /tmp/.tflint.hcl
USER root

# checkov
RUN apt-get update && apt-get install -y --no-install-recommends python3 python3-pip python3-venv \
  && apt-get clean && rm -rf /var/lib/apt/lists/* && \
  pip3 install --no-cache-dir checkov==${CHECKOV_VERSION} --break-system-packages

# terraform-docs
RUN ARCH="$(dpkg --print-architecture)" && \
  wget -q "https://github.com/terraform-docs/terraform-docs/releases/download/v${TERRAFORM_DOCS_VERSION}/terraform-docs-v${TERRAFORM_DOCS_VERSION}-linux-${ARCH}.tar.gz" && \
  tar -xzf "terraform-docs-v${TERRAFORM_DOCS_VERSION}-linux-${ARCH}.tar.gz" && \
  mv terraform-docs /usr/local/bin/ && rm "terraform-docs-v${TERRAFORM_DOCS_VERSION}-linux-${ARCH}.tar.gz" && \
  chmod +x /usr/local/bin/terraform-docs

# --- Backend tools ---

# Go
RUN ARCH="$(dpkg --print-architecture)" && \
  wget -q "https://go.dev/dl/go${GO_VERSION}.linux-${ARCH}.tar.gz" && \
  tar -C /usr/local -xzf "go${GO_VERSION}.linux-${ARCH}.tar.gz" && \
  rm "go${GO_VERSION}.linux-${ARCH}.tar.gz"

ENV PATH=$PATH:/usr/local/go/bin
ENV GOPATH=/home/node/go
ENV PATH=$PATH:/home/node/go/bin

RUN mkdir -p /home/node/go/bin && chown -R node:node /home/node/go

USER node

RUN go install mvdan.cc/gofumpt@v${GOFUMPT_VERSION} && \
  go install golang.org/x/tools/cmd/goimports@v${GOIMPORTS_VERSION} && \
  go install golang.org/x/vuln/cmd/govulncheck@v${GOVULNCHECK_VERSION} && \
  go install github.com/securego/gosec/v2/cmd/gosec@v${GOSEC_VERSION}

RUN go install github.com/golangci/golangci-lint/v2/cmd/golangci-lint@v${GOLANGCI_LINT_VERSION}

USER root

# osv-scanner
RUN ARCH="$(dpkg --print-architecture)" && \
  wget -q "https://github.com/google/osv-scanner/releases/download/v${OSV_SCANNER_VERSION}/osv-scanner_linux_${ARCH}" -O /usr/local/bin/osv-scanner && \
  chmod +x /usr/local/bin/osv-scanner

USER node

# --- Frontend tools ---

RUN npm install -g next@${NEXTJS_VERSION} react@${REACT_VERSION} react-dom@${REACT_VERSION} typescript@${TYPESCRIPT_VERSION} eslint@${ESLINT_VERSION} prettier@${PRETTIER_VERSION} \
  && npm install -g @openai/codex@${CODEX_VERSION}

RUN mkdir -p /home/node/.codex

WORKDIR /workspace

LABEL org.opencontainers.image.source="https://github.com/nakatatsu/mynote"
LABEL org.opencontainers.image.description="DevContainer Local Development Image"
LABEL maintainer="nakatatsu"
