#!/bin/bash
set +e  # Continue on errors to test all tools
# Test all installed tools and report their versions
# Usage: ./test-install.sh

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

QUICK_MODE=false
if [ "$1" = "--quick" ]; then
  QUICK_MODE=true
fi

FAILED=0
PASSED=0

# Test function
test_command() {
  local name="$1"
  local command="$2"

  printf "%-25s" "$name"

  if output=$(eval "$command" 2>&1); then
    # Extract version number (first line, remove extra text)
    version=$(echo "$output" | head -1 | sed 's/.*version //i' | sed 's/ .*//')
    echo -e "${GREEN}✓${NC} $version"
    ((PASSED++))
  else
    echo -e "${RED}✗ FAILED${NC}"
    ((FAILED++))
    if [ "$QUICK_MODE" = false ]; then
      echo "  Error: $output" | head -3
    fi
  fi
}

echo "============================================================================"
echo "DevContainer Installation Test"
echo "============================================================================"
echo ""

# ============================================================================
# Base Tools
# ============================================================================
echo "Base Tools:"
echo "------------"
test_command "Claude Code" "claude --version"
test_command "Node.js" "node --version"
test_command "npm" "npm --version"
test_command "git" "git --version"
test_command "GitHub CLI" "gh --version | head -1"
test_command "jq" "jq --version"
test_command "AWS CLI" "aws --version"
test_command "git-delta" "delta --version"
test_command "zsh" "zsh --version"
echo ""

# ============================================================================
# Infrastructure Tools
# ============================================================================
if command -v terraform &> /dev/null; then
  echo "Infrastructure Tools:"
  echo "---------------------"
  test_command "Terraform" "terraform version | head -1"
  test_command "tflint" "tflint --version"
  test_command "checkov" "checkov --version"
  test_command "terraform-docs" "terraform-docs --version"
  echo ""
fi

# ============================================================================
# Backend Tools
# ============================================================================
if command -v go &> /dev/null; then
  echo "Backend Tools:"
  echo "--------------"
  test_command "Go" "go version"
  test_command "gofumpt" "gofumpt -version"
  test_command "goimports" "goimports -h 2>&1 | head -1"
  test_command "golangci-lint" "golangci-lint --version"
  test_command "govulncheck" "govulncheck -version"
  test_command "osv-scanner" "osv-scanner --version"
  test_command "gosec" "gosec -version"
  echo ""
fi

# ============================================================================
# Frontend Tools
# ============================================================================
if command -v next &> /dev/null; then
  echo "Frontend Tools:"
  echo "---------------"
  test_command "Next.js" "next --version"
  test_command "TypeScript" "tsc --version"
  test_command "ESLint" "eslint --version"
  test_command "Prettier" "prettier --version"
  echo ""
fi

# ============================================================================
# Network Tools
# ============================================================================
echo "Network Tools:"
echo "--------------"
test_command "iptables" "iptables --version"
test_command "ipset" "ipset --version"
test_command "dig" "dig -v 2>&1 | head -1"
echo ""

# ============================================================================
# Summary
# ============================================================================
echo "============================================================================"
echo "Test Summary"
echo "============================================================================"
echo -e "${GREEN}Passed:${NC} $PASSED"
if [ $FAILED -gt 0 ]; then
  echo -e "${RED}Failed:${NC} $FAILED"
  exit 1
else
  echo -e "${GREEN}All tests passed!${NC}"
  exit 0
fi
