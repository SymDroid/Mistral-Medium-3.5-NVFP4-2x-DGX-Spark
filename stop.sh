#!/usr/bin/env bash
set -euo pipefail

docker rm -f mistral35 mistral35-worker 2>/dev/null || true
echo "mistral35 containers stopped."
