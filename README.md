# PQC TLS POC Benchmark

Proof-of-concept project to benchmark hybrid TLS (ECDH + ML-KEM) against classical TLS.

## Architecture

Client → Quantum TLS Gateway → Backend API

The gateway is provider-agnostic and supports multiple crypto backends:

- AWS s2n-tls
- OpenSSL + OQS
- Cloudflare PQC (BoringSSL)
- NVIDIA experimental provider

## Goals

1. Compare classical TLS vs hybrid PQC TLS
2. Measure handshake latency
3. Measure request latency
4. Measure throughput
5. Measure CPU cost

## Running

```bash
docker compose up
```

Then run benchmarks:

```bash
python benchmark/run_benchmark.py
```