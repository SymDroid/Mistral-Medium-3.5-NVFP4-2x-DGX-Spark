# Mistral Medium 3.5 128B NVFP4 on 2× DGX Spark

[![License: MIT](https://img.shields.io/badge/License-MIT-yellow.svg)](LICENSE)
![DGX Spark](https://img.shields.io/badge/NVIDIA-DGX%20Spark-76B900)
![vLLM](https://img.shields.io/badge/vLLM-26.05-blue)
![Context](https://img.shields.io/badge/context-262K-purple)

Community deployment recipe by **SymDroid** for running Mistral Medium 3.5 128B NVFP4 across two NVIDIA DGX Spark systems.

Reproducible two-node vLLM recipe for serving **Mistral Medium 3.5 128B NVFP4**
across **2× NVIDIA DGX Spark** using **Ray + tensor parallelism 2** over the
dedicated QSFP/NCCL fabric.

## Tested configuration

- 2× DGX Spark
- 256 GB unified memory total
- Mistral Medium 3.5 128B NVFP4
- NVIDIA vLLM container `nvcr.io/nvidia/vllm:26.05-py3`
- Ray distributed executor
- TP=2
- NCCL over `enP2p1s0f1np1`
- 262,144-token maximum context
- 72% vLLM GPU memory utilization
- Prefix caching enabled
- OpenAI-compatible API
- Mistral tool-call parser + automatic tool choice

Observed on the reference setup:

| Metric | Result |
|---|---:|
| Head RAM usage | ~103 GB |
| Worker RAM usage | ~107 GB |
| Single-request generation | ~3.7–3.8 tok/s |
| Aggregate generation, concurrency 2 | ~6.8–7.0 tok/s |
| Maximum model context | 262K |
| API port | 8017 |

These are measurements from one setup, not guaranteed performance figures.

## Topology

```text
DGX Sparkx / head
192.168.100.11
       |
       | QSFP / NCCL / Ray
       |
192.168.100.10
DGX Spark / worker

TP rank 0 <--------> TP rank 1
       |
       +--> OpenAI API :8017
```

## 1. Install the recipe on both Sparks

```bash
git clone https://github.com/SymDroid/Mistral-Medium-3.5-NVFP4-2x-DGX-Spark.git
cd mistral-medium-3.5-nvfp4-2x-dgx-spark

cp .env.example .env
chmod +x *.sh
```

The model must exist at the same path on both machines:

```text
/home/symdroid/models/mistralai/mistral-medium-3.5-nvfp4
```

Adjust `.env` if your paths, IPs, interface or API port differ.

## 2. Start the head

On **DGX Sparkx / 192.168.100.11**:

```bash
./start-head.sh
```

The head starts Ray and waits until the cluster reports two GPUs.

Follow the logs:

```bash
docker logs -f mistral35
```

## 3. Start the worker

On **DGX Spark / 192.168.100.10**:

```bash
./start-worker.sh
```

Follow the logs:

```bash
docker logs -f mistral35-worker
```

As soon as the worker joins Ray, the head should detect `/2.0 GPU` and launch
vLLM.

## 4. Check the API

From either host:

```bash
curl http://192.168.100.11:8017/v1/models
```

Or:

```bash
./test-api.sh
```

The OpenAI-compatible base URL is:

```text
http://192.168.100.11:8017/v1
```

For Onyx, use that URL and the served model name:

```text
mistral35
```

## Important vLLM flags

```text
--tensor-parallel-size 2
--distributed-executor-backend ray
--max-model-len 262144
--gpu-memory-utilization 0.72
--enable-prefix-caching
--enforce-eager
--disable-custom-all-reduce
--tool-call-parser mistral
--enable-auto-tool-choice
```

### Why `--disable-custom-all-reduce`?

The cluster uses two physical DGX Spark nodes rather than multiple GPUs inside
one conventional CUDA host. NCCL handles cross-node collective communication.

### Why `--enforce-eager`?

This is retained from the known-good reference configuration. It avoids CUDA
graph behaviour that may be undesirable or unstable for this distributed
GB10 setup. Remove only after benchmarking and validating the cluster.

### Why prefix caching?

Repeated prompt prefixes can reuse cached KV blocks. This is particularly
useful for agentic/RAG workloads in which long system prompts, tool
descriptions, or shared document context recur across requests.

## Useful commands

```bash
# Head logs
docker logs -f mistral35

# Worker logs
docker logs -f mistral35-worker

# Resource usage
docker stats mistral35
docker stats mistral35-worker

# NVIDIA telemetry
nvidia-smi

# Stop local containers
./stop.sh
```

## Notes

`start-head.sh` waits for both GPUs before launching vLLM. Therefore the normal
startup order is:

1. head
2. worker
3. Ray sees 2 GPUs
4. vLLM launches TP=2
5. API becomes available on port 8017

The scripts install Ray inside the NVIDIA vLLM container at startup, matching
the original working Docker commands. For a more immutable production image,
Ray can later be baked into a custom Docker image instead.


## Disclaimer

This is an independent community recipe and is not affiliated with or endorsed by Mistral AI or NVIDIA. Model licensing remains subject to the upstream model license.
