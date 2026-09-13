#!/usr/bin/env bash
set -euo pipefail

cd "$(dirname "$0")"
if [[ -f .env ]]; then
  set -a
  source .env
  set +a
else
  echo "Missing .env. Run: cp .env.example .env"
  exit 1
fi

docker rm -f mistral35-worker >/dev/null 2>&1 || true

docker run -d \
  --name mistral35-worker \
  --restart unless-stopped \
  --network host \
  --shm-size "${SHM_SIZE}" \
  --gpus all \
  -e VLLM_HOST_IP="${WORKER_IP}" \
  -e UCX_NET_DEVICES="${FABRIC_IFACE}" \
  -e NCCL_SOCKET_IFNAME="${FABRIC_IFACE}" \
  -e OMPI_MCA_btl_tcp_if_include="${FABRIC_IFACE}" \
  -e GLOO_SOCKET_IFNAME="${FABRIC_IFACE}" \
  -e TP_SOCKET_IFNAME="${FABRIC_IFACE}" \
  -e RAY_memory_monitor_refresh_ms=0 \
  -e MASTER_ADDR="${HEAD_IP}" \
  -v "${MODEL_ROOT}:${MODEL_ROOT}:ro" \
  -v "${HF_CACHE}:/root/.cache/huggingface" \
  --entrypoint /bin/bash \
  "${VLLM_IMAGE}" \
  -lc "
    set -e

    pip install -q --root-user-action=ignore 'ray[default]>=2.9'

    echo 'Joining Ray head at ${HEAD_IP}:${RAY_PORT}...'

    exec ray start \
      --block \
      --address='${HEAD_IP}:${RAY_PORT}' \
      --node-ip-address='${WORKER_IP}'
  "

echo
echo "Worker container started."
echo "Logs: docker logs -f mistral35-worker"
