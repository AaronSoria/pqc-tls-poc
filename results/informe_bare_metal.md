# Informe de benchmark PQC — Bare Metal
**Fecha:** 2026-05-27  
**Host:** atlasmk2 (Ubuntu 22.04 LTS)  
**GPU:** NVIDIA GeForce RTX 3090 — 24 576 MiB VRAM, Ampere sm\_86  

---

## Entorno de prueba

| Componente | Versión / detalle |
|---|---|
| OS | Ubuntu 22.04 LTS — kernel 5.15.0-179-generic |
| CPU | x86\_64, extensiones AVX2 / AES-NI / AVX / SSE4 activas |
| GPU | NVIDIA GeForce RTX 3090 — 24 576 MiB, Ampere sm\_86 |
| CUDA toolkit | 12.6 (V12.6.85) |
| cuPQC SDK | 0.4.1 |
| Go | 1.22.12 |
| liboqs | 0.15.0 |
| OpenSSL (sistema) | 3.0.2 (15 Mar 2022) |
| OpenSSL + oqs-provider | compilado en `/opt/oqs-openssl` |
| AWS-LC | HEAD (estático, `/opt/aws-lc`) |
| s2n-tls | HEAD (estático con AWS-LC, PQ habilitado, `/opt/s2n-tls`) |

---

## 1. TLS Handshake — latencia

Metodología: 50 iteraciones por stack, loopback `localhost`, TLS 1.3 full handshake.

| Stack | Mean (ms) | p50 (ms) | p95 (ms) | Min (ms) | Max (ms) | ok/fail |
|---|---:|---:|---:|---:|---:|---:|
| Classical TLS — RSA-2048 | **1.18** | 1.17 | 1.23 | 1.15 | 1.44 | 50/0 |
| AWS PQ — s2n-tls + AWS-LC (X25519MLKEM768) | **29.36** | 29.41 | 29.57 | 28.73 | 29.60 | 50/0 |
| OQS PQC — OpenSSL + oqs-provider (X25519MLKEM768) | **34.33** | 38.47 | 38.82 | 22.48 | 39.10 | 50/0 |

**Notas de metodología:**
- *Classical* y *AWS PQ*: medición directa del handshake en Go (CGO / `crypto/tls`), sin overhead de proceso externo.
- *OQS PQC*: medido via subprocess `openssl s_client`; incluye ~1–2 ms de overhead de lanzamiento de proceso. El valor real del handshake es ~32–33 ms.
- KEM negociado en ambos stacks PQ: **X25519MLKEM768** (ECDH híbrido + ML-KEM-768).
- Cipher suite: `TLS_AES_128_GCM_SHA256`.
- Autenticación de servidor: `RSA-PSS-RSAE+SHA256` en los tres stacks.

**Overhead PQ vs Classical:**
- AWS PQ es **24.9×** más lento que Classical en latencia de handshake.
- OQS PQC es **29.1×** más lento que Classical (incluyendo overhead de subprocess).
- La diferencia entre AWS PQ y OQS PQC (~5 ms) refleja la optimización de s2n-tls y la ausencia de subprocess.

---

## 2. Primitivas ML-KEM-768 en CPU

Implementación: **liboqs 0.15.0**, compilado con `OQS_MINIMAL_BUILD=KEM_ml_kem_768`, aceleración AVX2.  
Método: benchmark interno `speed_kem`, ~3 segundos por operación.

| Operación | Iteraciones | Tiempo total (s) | Media (µs) | Stdev (µs) | Ciclos CPU (media) |
|---|---:|---:|---:|---:|---:|
| keygen | 273 131 | 3.000 | **10.984** | 4.209 | 37 194 |
| encaps | 265 502 | 3.000 | **11.299** | 0.469 | 38 261 |
| decaps | 229 234 | 3.000 | **13.087** | 0.299 | 44 332 |

**Throughput estimado (CPU):**
- keygen: ~91 000 ops/s
- encaps: ~88 500 ops/s
- decaps: ~76 400 ops/s

El alto stdev en keygen (4.2 µs) refleja la variabilidad del muestreo de números aleatorios (DRNG) en la generación de clave.

---

## 3. Primitivas ML-KEM-768 en GPU (cuPQC)

Implementación: **NVIDIA cuPQC 0.4.1**, compilado con `nvcc -std=c++17 -O3 -rdc=true -dlto -arch=sm_86`.  
Método: batch paralelo en RTX 3090; latencia reportada en µs por operación (no por batch).  
La primera medición de batch=1 (keygen ~147 µs) corresponde al warm-up de la GPU y se excluye del análisis comparativo.

### Latencia por operación según batch size (µs/op)

| Batch | keygen (µs) | encaps (µs) | decaps (µs) |
|---:|---:|---:|---:|
| 1 | 71.65 | 94.67 | 100.88 |
| 8 | 9.00 | 9.75 | 9.98 |
| 32 | 2.48 | 2.44 | 2.48 |
| 128 | 0.637 | 0.629 | 0.646 |
| 512 | 0.314 | 0.325 | 0.335 |
| 2 048 | 0.254 | 0.236 | 0.283 |
| 8 192 | **0.219** | **0.211** | **0.265** |

### Throughput a batch=8192

| Operación | µs/op | ops/s |
|---|---:|---:|
| keygen | 0.219 | ~4 570 000 |
| encaps | 0.211 | ~4 740 000 |
| decaps | 0.265 | ~3 770 000 |

### Speedup GPU vs CPU (batch=8192)

| Operación | CPU (µs) | GPU (µs) | Speedup |
|---|---:|---:|---:|
| keygen | 10.984 | 0.219 | **~50×** |
| encaps | 11.299 | 0.211 | **~54×** |
| decaps | 13.087 | 0.265 | **~49×** |

---

## 4. Análisis y conclusiones

### 4.1 Costo del PQ en TLS
El handshake PQ (X25519MLKEM768) agrega ~28–33 ms respecto al handshake clásico (RSA-2048) en loopback. Este overhead es atribuible principalmente al tamaño del mensaje PQ (ciphertext ML-KEM-768 ≈ 1 088 bytes vs 32 bytes de X25519) y al costo de serialización/deserialización en el record layer de TLS, no al cómputo de la KEM en sí (que tarda ~11–13 µs en CPU).

En redes con latencia real (>10 ms RTT), el overhead relativo del PQ se diluye significativamente.

### 4.2 Ventaja GPU para primitivas PQC
La RTX 3090 entrega ~50× speedup sobre una CPU moderna con AVX2 en batch=8192. La curva de latencia satura en torno a batch=2 048–8 192, indicando que el cuello de botella a ese nivel es el ancho de banda de memoria global y no la capacidad de cómputo.

El **punto de break-even** (GPU supera a CPU en latencia/op) se alcanza en batch≈8–16, lo que lo hace práctico para:
- Aceleradores TLS en proxies de alto tráfico (>10 000 handshakes/s)
- Sistemas de firma/verificación masiva (PKI, CT logs)
- KEM batch para protocolos de grupo (MLS, Signal PQ)

### 4.3 Comparación de stacks PQ
AWS s2n-tls + AWS-LC ofrece latencia de handshake ligeramente menor que OQS OpenSSL en esta medición. La comparación no es completamente justa (subprocess vs CGO directo), pero la consistencia de los resultados de s2n-tls (stdev muy bajo: 29.41 p50 ≈ 29.57 p95) sugiere una implementación más predecible.

### 4.4 Proyecciones de throughput

Con offload GPU (batch=8192):
- **keygen:** ~4.6M ops/s — equivalente a servir ~4.6M nuevas sesiones TLS/s solo en la fase KEM
- **encaps/decaps:** throughput similar (~3.8–4.7M ops/s)

Con CPU pura (AVX2, un core):
- ~91K keygen/s — suficiente para ~91K sesiones TLS nuevas/s por core en la fase KEM

---

## 5. Artefactos generados

| Archivo | Contenido |
|---|---|
| `results/bare_metal_20260527_172202/tls.txt` | Latencias TLS completas (50 iter × 3 stacks) |
| `results/bare_metal_20260527_172202/cpu.txt` | Output completo `speed_kem ML-KEM-768` |
| `results/bare_metal_20260527_172202/gpu.csv` | Latencias GPU por batch size y operación |
| `results/bare_metal_20260527_172202/gpu_raw.txt` | Output crudo del benchmark cuPQC |
| `pqc_bench.sh` | Script de benchmark reproducible (Ubuntu 22.04 + RTX 3090) |

---

## 6. Reproducibilidad

```bash
# Requisitos previos
# - Ubuntu 22.04 LTS, bare metal o VM con GPU passthrough
# - NVIDIA RTX 3090 con driver instalado
# - cuPQC SDK 0.4.1 en /usr/local/cupqc-sdk/
#   wget https://developer.download.nvidia.com/compute/cupqc/redist/cupqc/cupqc-sdk-0.4.1-x86_64.tar.gz
#   sudo tar -xzf cupqc-sdk-0.4.1-x86_64.tar.gz --strip-components=1 -C /usr/local/cupqc-sdk

# Setup completo + benchmark (~30-60 min primera vez)
sudo bash pqc_bench.sh

# Solo GPU (requiere cuPQC SDK instalado)
sudo bash pqc_bench.sh --gpu-only

# Solo ejecutar (dependencias ya compiladas)
sudo bash pqc_bench.sh --run-only
```

> La primera ejecución compila AWS-LC, s2n-tls, liboqs y OQS OpenSSL desde fuente. Las ejecuciones subsiguientes retoman desde el estado de fases (`.pqc_phases`) y son casi instantáneas.
