# 🧪 PQC TLS POC – Benchmark TLS Clásico vs Post-Cuántico

## 📌 Descripción

Este proyecto implementa un entorno reproducible para evaluar el rendimiento de:

* 🔐 TLS clásico (OpenSSL)
* 🔐 TLS híbrido post-cuántico (OpenSSL + liboqs + oqs-provider)

El objetivo es medir el impacto del uso de criptografía post-cuántica (PQC) en el **handshake TLS** y comparar métricas como latencia.

---

# 🏗️ Arquitectura

```text
benchmark (cliente)
   ├── classical-server (TLS clásico)
   └── oqs-server (TLS híbrido PQC)
```

---

# ⚙️ Requisitos

* Docker ≥ 24
* Docker Compose ≥ v2
* Linux recomendado (probado en Ubuntu / Pop!_OS)

---

# 🚀 Cómo ejecutar

## 1️⃣ Clonar el repositorio

```bash
git clone <repo-url>
cd pqc-tls-poc
```

---

## 2️⃣ Construir imágenes

```bash
docker compose build --no-cache
```

> ⚠️ La build puede tardar varios minutos debido a la compilación de:
>
> * OpenSSL
> * liboqs
> * oqs-provider

---

## 3️⃣ Ejecutar el entorno

```bash
docker compose up
```

---

## 4️⃣ Qué sucede al ejecutar

El sistema realiza automáticamente:

```text
1. Levanta classical-server (TLS clásico)
2. Levanta oqs-server (TLS PQC)
3. Espera a que ambos estén disponibles
4. Ejecuta benchmark
5. Muestra resultados en consola
```

---

## 📊 Output esperado

```text
Provider             Latency (ms)
-----------------------------------
Classical TLS        ~2.0
PQC TLS              ~3.5
```

> ⚠️ Los valores pueden variar según hardware

---

# 🧪 Detalles técnicos

## 🔸 TLS Clásico

* OpenSSL estándar
* RSA 2048
* Handshake tradicional

---

## 🔸 TLS PQC

* OpenSSL compilado manualmente
* liboqs integrado
* oqs-provider cargado dinámicamente
* Grupo híbrido utilizado:

```text
X25519MLKEM768
```

---

## 🔸 Benchmark

* Implementado en Python
* Mide:

  * tiempo de conexión TCP + handshake TLS
* Ejecuta:

  * cliente clásico (socket + ssl)
  * cliente PQC (openssl s_client)

---

# 🧰 Comandos útiles

## 🔹 Ver logs

```bash
docker compose logs -f
```

---

## 🔹 Reiniciar entorno

```bash
docker compose down
docker compose up --build
```

---

## 🔹 Ejecutar benchmark manualmente

```bash
docker compose exec benchmark python -m benchmark.run_benchmark
```

---

# ⚠️ Problemas conocidos

## ❌ Error: provider no carga

Verificar:

```bash
echo $OPENSSL_MODULES
```

Debe ser:

```text
/usr/local/lib/ossl-modules
```

---

## ❌ Error: conexión rechazada

Puede deberse a:

* servidores no listos
* falta de espera inicial

Solución: aumentar delay en benchmark

---

## ❌ Error: grupos PQC no reconocidos

Usar:

```text
X25519MLKEM768
```

No usar:

```text
kyber512 ❌
```

---

# 📁 Estructura del proyecto

```text
.
├── docker-compose.yml
├── oqs-server/
│   └── Dockerfile
├── benchmark/
│   ├── run_benchmark.py
│   └── client/
│       ├── classical_client.py
│       └── pqc_client.py
```

---

# 📈 Próximos pasos

* Integración con AWS (s2n-tls, AWS-LC)
* Benchmark en infraestructura real (EC2)
* Validación con AWS KMS
* Observabilidad con CloudWatch
* Evaluación de aceleración con NVIDIA (CUDA)

---

# 🏁 Conclusión

Este entorno permite evaluar de forma controlada el impacto de la criptografía post-cuántica en TLS, sirviendo como base para pruebas más avanzadas en entornos reales.

---
