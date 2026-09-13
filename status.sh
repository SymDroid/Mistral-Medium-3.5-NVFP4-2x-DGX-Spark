#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"
if [[ -f .env ]]; then
  set -a
  source .env
  set +a
fi

echo "=== Docker ==="
docker ps --filter "name=e-symistral" \
  --format "table {{.Names}}\t{{.Status}}\t{{.Image}}"

echo
echo "=== API ==="
if [[ -n "${HEAD_IP:-}" && -n "${API_PORT:-}" ]]; then
  curl -fsS "http://${HEAD_IP}:${API_PORT}/v1/models" | python3 -m json.tool || true
else
  echo "No .env loaded."
fi
