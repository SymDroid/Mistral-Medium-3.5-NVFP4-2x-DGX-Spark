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

docker rm -f mistral35 >/dev/null 2>&1 || true

docker run -d \
  --name mistral35 \
  --restart unless-stopped \
  --network host \
  --shm-size "${SHM_SIZE}" \
  --gpus all \
  -e VLLM_HOST_IP="${HEAD_IP}" \
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

    ray start \
      --head \
      --node-ip-address='${HEAD_IP}' \
      --port='${RAY_PORT}'

    echo 'Waiting for second DGX Spark...'

    until ray status 2>/dev/null | grep -q '/2.0 GPU'; do
      sleep 2
    done

    echo '2 GPUs detected. Starting ${SERVED_MODEL_NAME}.'

    exec vllm serve '${MODEL_PATH}' \
      --served-model-name '${SERVED_MODEL_NAME}' \
      --host 0.0.0.0 \
      --port '${API_PORT}' \
      --tensor-parallel-size '${TENSOR_PARALLEL_SIZE}' \
      --distributed-executor-backend ray \
      --max-model-len '${MAX_MODEL_LEN}' \
      --gpu-memory-utilization '${GPU_MEMORY_UTILIZATION}' \
      --enable-prefix-caching \
      --enforce-eager \
      --disable-custom-all-reduce \
      --tool-call-parser mistral \
      --enable-auto-tool-choice
  "

echo
echo "Head container started."
echo "Logs:   docker logs -f mistral35"
echo "API:    http://${HEAD_IP}:${API_PORT}/v1"
