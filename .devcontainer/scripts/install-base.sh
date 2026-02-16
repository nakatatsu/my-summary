#!/bin/bash
set -euo pipefail
# Install common base tools for all DevContainer images
# Usage: Called from Dockerfiles during build

# Install system packages
apt-get update && apt-get install -y --no-install-recommends \
  less git procps sudo fzf zsh man-db unzip gnupg2 gh jq nano vim \
  iptables ipset iproute2 dnsutils aggregate curl \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

# Install AWS CLI
ARCH=$(uname -m)
if [ "$ARCH" = "x86_64" ]; then
  curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64-${AWS_CLI_VERSION}.0.zip" -o "awscliv2.zip"
elif [ "$ARCH" = "aarch64" ]; then
  curl "https://awscli.amazonaws.com/awscli-exe-linux-aarch64-${AWS_CLI_VERSION}.0.zip" -o "awscliv2.zip"
fi
unzip awscliv2.zip && ./aws/install && rm -rf aws awscliv2.zip

# User configuration
USERNAME=node
mkdir -p /usr/local/share/npm-global && chown -R node:node /usr/local/share

# Bash history
mkdir /commandhistory && touch /commandhistory/.bash_history && chown -R $USERNAME /commandhistory

# Workspace and Claude config
mkdir -p /workspace /home/node/.claude && chown -R node:node /workspace /home/node/.claude

# Install git-delta
ARCH=$(dpkg --print-architecture)
wget "https://github.com/dandavison/delta/releases/download/${GIT_DELTA_VERSION}/git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb"
dpkg -i "git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb"
rm "git-delta_${GIT_DELTA_VERSION}_${ARCH}.deb"
