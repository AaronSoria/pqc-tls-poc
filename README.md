# 🔐 PQC TLS Benchmark — Classical vs Post-Quantum Cryptography (CPU & GPU)

## 📌 Overview

This repository presents a **comprehensive experimental evaluation of post-quantum cryptography (PQC)** in the context of TLS, combining:

* 🔐 Classical TLS (OpenSSL / AWS-LC)
* 🔐 Hybrid PQC TLS (X25519 + ML-KEM-768)
* ⚙️ CPU-based PQC primitives (liboqs)
* 🚀 GPU-accelerated PQC primitives (NVIDIA cuPQC)

The goal is to **quantify the real-world performance impact of PQC**, from protocol-level behavior (TLS handshake) down to cryptographic primitive execution.

---

# 🎯 Research Objectives

This work aims to answer:

1. What is the **performance overhead of PQC in TLS handshakes**?
2. Is PQC computation itself the **primary bottleneck**?
3. Can **GPU acceleration (cuPQC)** mitigate PQC overhead?
4. How do **latency vs throughput trade-offs** behave in PQC systems?

---

# 🏗️ System Architecture

```text
Client
  │
Hybrid TLS (X25519 + ML-KEM-768)
  │
Quantum TLS Gateway / Server
  │
Backend API
```



---

# 🧪 Experimental Design

## 1️⃣ TLS Benchmark (AWS / s2n-tls)

* Full TLS 1.3 handshake (no reuse)
* Hybrid key exchange: **X25519 + ML-KEM-768**
* Real network environment (EC2)

### Results

| Metric         | Classical TLS | PQC TLS          |
| -------------- | ------------- | ---------------- |
| Latency        | ~2.5–2.8 ms   | ~95–96 ms        |
| Overhead       | —             | **~93 ms**       |
| Handshake size | —             | ~2409 bytes (in) |



---

## 2️⃣ CPU Benchmark (liboqs)

Environment:

* liboqs v0.15.0
* AVX2 enabled
* OpenSSL 3.6

### Results (μs/op)

| Operation | Latency  |
| --------- | -------- |
| keygen    | 9.56 μs  |
| encaps    | 9.75 μs  |
| decaps    | 12.20 μs |



---

## 3️⃣ GPU Benchmark (NVIDIA cuPQC)

* CUDA + cuPQC SDK
* ML-KEM-768
* Batched execution

### Results (μs/op)

| Batch | Keygen   | Encaps   | Decaps   |
| ----- | -------- | -------- | -------- |
| 1     | ~100     | ~99      | ~101     |
| 8192  | **0.82** | **0.96** | **1.02** |



---

# 📊 Key Findings

## 🔴 1. PQC overhead in TLS is significant

* ~93 ms additional latency in full handshake
* ~35× slower than classical TLS

👉 However:

> This overhead occurs primarily during **cold handshake** scenarios.



---

## 🧠 2. Cryptography is NOT the bottleneck

Compare:

* ML-KEM (CPU): ~10 μs
* TLS overhead: ~93,000 μs

👉 PQC computation accounts for:

```text
< 0.02% of total handshake latency
```

---

## ⚠️ 3. GPU does NOT improve latency

| Scenario         | GPU Performance     |
| ---------------- | ------------------- |
| Single operation | ❌ Worse (~100 μs)   |
| Batched (8192)   | ✅ Excellent (~1 μs) |

👉 GPU is **throughput-oriented**, not latency-oriented.

---

## 🚀 4. GPU enables massive scalability

Approximate throughput:

* CPU: ~100K ops/sec
* GPU: ~1M ops/sec

👉 ~10× improvement in high-concurrency environments

---

## 💡 5. Critical Insight

> Accelerating PQC primitives does NOT reduce TLS handshake latency.

Instead:

* TLS overhead is dominated by:

  * network latency
  * message size
  * protocol orchestration

---

# 🧠 Interpretation

This work demonstrates a key distinction:

| Layer                    | Impact            |
| ------------------------ | ----------------- |
| Cryptographic primitives | Low latency cost  |
| Protocol (TLS)           | High latency cost |

---

# ⚙️ Repository Structure

```text
.
├── gpu/                # cuPQC benchmarks
├── cpu/                # liboqs baseline
├── docker/             # TLS benchmark environment
├── results/            # experimental outputs
├── docs/               # bitácora + notes
└── README.md
```

---

# 🚀 Reproducibility

## GPU Benchmark

```bash
cd gpu
./build.sh
./run.sh
```

---

## CPU Benchmark

```bash
cd cpu
./build.sh
./run_cpu.sh
```

---

## TLS Benchmark

```bash
docker compose up --build
```

---

# ⚠️ Methodological Notes

* GPU measurements correspond to **kernel execution only**
* TLS benchmarks measure **full handshake latency**
* No session reuse (worst-case scenario)
* Results emphasize **cold-start performance**

---

# 📈 Practical Implications

## Where GPU helps

✔ TLS termination at scale
✔ CDN edge nodes
✔ high-throughput APIs

---

## Where GPU does NOT help

❌ Individual TLS handshakes
❌ latency-sensitive connections

---

# 🔮 Future Work

* Integration with **AWS KMS PQC endpoints**
* End-to-end TLS proxy architecture (crypto-agility)
* Throughput benchmarking under real load
* CUDA optimization (memory + streams)



---

# 🏁 Conclusion

This project provides a **multi-layer evaluation of PQC systems**, demonstrating that:

* PQC introduces **significant protocol-level overhead**
* Cryptographic computation is **not the limiting factor**
* GPU acceleration is effective only under **high parallelism**

> The transition to PQC requires **protocol-level optimization**, not just faster cryptography.

---

# 📚 References

* Open Quantum Safe (liboqs)
* AWS s2n-tls / AWS-LC
* NVIDIA cuPQC
* NIST FIPS 203 (ML-KEM)

---

# 👤 Author

Aaron Soria

---
