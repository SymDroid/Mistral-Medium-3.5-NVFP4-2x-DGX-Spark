#!/usr/bin/env bash
set -euo pipefail

docker rm -f e-symistral e-symistral-worker 2>/dev/null || true
echo "e-symistral containers stopped."
