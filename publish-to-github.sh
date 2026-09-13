#!/usr/bin/env bash
set -euo pipefail

REPO="Mistral-Medium-3.5-NVFP4-2x-DGX-Spark"
OWNER="SymDroid"

if ! command -v gh >/dev/null 2>&1; then
  echo "GitHub CLI (gh) is required. Install it first: https://cli.github.com/"
  exit 1
fi

if ! gh auth status >/dev/null 2>&1; then
  echo "Not authenticated. Run: gh auth login"
  exit 1
fi

git init -b main

git add .
git commit -m "Initial DGX Spark recipe for Mistral Medium 3.5 NVFP4"

gh repo create "$OWNER/$REPO" \
  --public \
  --source=. \
  --remote=origin \
  --push \
  --description "Run Mistral Medium 3.5 128B NVFP4 across 2x NVIDIA DGX Spark with vLLM, Ray TP2 and NCCL over QSFP."

echo
echo "Published: https://github.com/$OWNER/$REPO"
