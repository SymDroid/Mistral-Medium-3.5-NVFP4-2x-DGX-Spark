#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"
set -a
source .env
set +a

curl -sS "http://${HEAD_IP}:${API_PORT}/v1/chat/completions" \
  -H "Content-Type: application/json" \
  -d "{
    \"model\": \"${SERVED_MODEL_NAME}\",
    \"messages\": [
      {
        \"role\": \"user\",
        \"content\": \"Reply with exactly: Mistral cluster online\"
      }
    ],
    \"temperature\": 0,
    \"max_tokens\": 32
  }" | python3 -m json.tool
