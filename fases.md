# 🚀 Plan de Siguientes Pasos – Evaluación TLS Clásico vs PQC

## 🎯 Objetivo General

Extender el entorno experimental actual hacia una **arquitectura alineada con implementaciones industriales (AWS y NVIDIA)**, permitiendo evaluar:

* crypto-agility
* rendimiento en entornos reales
* impacto operativo del uso de criptografía post-cuántica

---

# 🧱 Estado Actual (Baseline)

Actualmente el proyecto cuenta con:

```text
✔ TLS clásico funcional (OpenSSL)
✔ TLS post-cuántico funcional (OpenSSL + liboqs + oqs-provider)
✔ Entorno reproducible con Docker
✔ Benchmark inicial de latencia de handshake
```

Este entorno sirve como **línea base experimental** para comparar futuras implementaciones.

---

# 🧭 Fase 1 – Arquitectura Crypto-Agile (Proxy)

## 🎯 Objetivo

Migrar desde un modelo de laboratorio a un modelo de arquitectura realista basado en proxy:

```text
client → pqc-proxy → backend
```

---

## ⚙️ Implementación

### 🔸 Crear servicio `pqc-proxy`

Responsabilidades:

* Terminar conexión TLS híbrida (ECDH + ML-KEM)
* Reenviar tráfico hacia backend clásico
* Permitir fallback a TLS clásico

---

### 🔸 Stack tecnológico

* s2n-tls (implementación TLS de AWS)
* AWS-LC (biblioteca criptográfica)

---

## 🧠 Resultado esperado

```text
✔ Separación del canal PQC
✔ Simulación de migración progresiva (crypto-agility)
✔ Base para despliegue en cloud
```

---

# ☁️ Fase 2 – Despliegue en AWS

## 🎯 Objetivo

Ejecutar la POC en infraestructura real.

---

## ⚙️ Infraestructura mínima

* Instancia EC2 (Ubuntu)
* Security Group:

  * Puerto 443 (TLS)
  * SSH (administración)

---

## 🧩 Arquitectura

```text
Local client → EC2 (pqc-proxy) → backend mock
```

---

## ⚙️ Implementación clave

Reemplazar:

```text
OpenSSL s_server
```

por:

```text
Servidor basado en s2n-tls
```

---

## 🔧 Configuración requerida

* TLS 1.3 obligatorio
* Preferencia de grupos híbridos:

```text
X25519 + ML-KEM-768
```

---

## 🧠 Consideración técnica clave

El componente PQC:

```text
✔ Se utiliza en el intercambio de claves (handshake)
✖ NO cifra directamente los datos
```

---

# 🧪 Fase 3 – Cliente AWS CRT (Opcional)

## 🎯 Objetivo

Simular comportamiento de cliente real AWS.

---

## ⚙️ Implementación

Uso de AWS Common Runtime (CRT):

```java
postQuantumTlsEnabled(true)
```

---

## 🧠 Resultado esperado

```text
✔ Negociación TLS híbrida real
✔ Validación compatible con entorno AWS
```

---

# 📊 Fase 4 – Benchmark Avanzado

## 🎯 Objetivo

Expandir el benchmark actual hacia métricas de nivel productivo.

---

## 📏 Métricas a medir

### 🔹 1. Latencia de handshake

* Ya implementada
* Aumentar número de iteraciones

---

### 🔹 2. Latencia end-to-end

```text
client → proxy → backend → response
```

---

### 🔹 3. Reutilización de conexiones (TLS reuse)

```text
Sin reuse → mayor latencia
Con reuse → impacto casi nulo
```

---

### 🔹 4. Throughput

* Requests por segundo

---

### 🔹 5. Uso de recursos

* CPU
* Memoria

---

# 📡 Fase 5 – Observabilidad

## 🎯 Objetivo

Obtener evidencia técnica medible del comportamiento del sistema.

---

## ⚙️ Implementación

Integración con Amazon CloudWatch:

* Métricas:

  * latencia
  * CPU
  * memoria
  * error rate
* Logs:

  * eventos TLS
  * fallbacks
  * errores

---

# 🔍 Fase 6 – Validación con AWS KMS

## 🎯 Objetivo

Validar comportamiento contra un endpoint real con soporte PQC.

---

## ⚙️ Implementación

* Ejecutar cliente contra AWS KMS
* Verificar negociación híbrida

---

## 🧪 Validación esperada

```text
tlsDetails.keyExchange = X25519MLKEM768
```

---

## 🧠 Importancia

```text
✔ Evidencia real en entorno productivo
✔ Validación independiente del laboratorio local
```

---

# ⚡ Fase 7 – Evaluación con NVIDIA

## 🎯 Objetivo

Analizar optimización de operaciones criptográficas mediante GPU.

---

## ⚙️ Enfoque

* No se reemplaza TLS directamente
* Se optimizan operaciones criptográficas internas

---

## 🔧 Experimentos

* Comparación CPU vs GPU:

  * ML-KEM
  * operaciones criptográficas intensivas
* Procesamiento en batch

---

## 🛠️ Tecnologías

* CUDA
* cuQuantum

---

## 📊 Métricas

* tiempo por operación
* escalabilidad
* consumo de recursos

---

# 🧠 Resumen Ejecutivo

El proyecto evoluciona hacia:

```text
1. Arquitectura basada en proxy (crypto-agility)
2. Implementación con stack AWS (s2n-tls + AWS-LC)
3. Despliegue en infraestructura real (EC2)
4. Benchmark completo (latencia, throughput, CPU)
5. Validación contra servicios AWS (KMS)
6. Observabilidad con CloudWatch
7. Optimización con NVIDIA (GPU)
```

---

# 📅 Plan de Ejecución Sugerido

```text
Día 1–2:
✔ Implementación de pqc-proxy con s2n-tls

Día 3–4:
✔ Despliegue en AWS EC2

Día 5:
✔ Benchmark y recolección de métricas

Día 6:
✔ Validación contra AWS KMS

Día 7:
✔ Documentación y análisis de resultados
```

---

# 🏁 Conclusión

El siguiente paso del proyecto consiste en transicionar desde un entorno experimental controlado hacia una **evaluación comparativa en entornos reales**, incorporando tecnologías de AWS y NVIDIA.

Esto permitirá analizar no solo la viabilidad técnica del TLS híbrido, sino también su impacto operativo y su aplicabilidad en sistemas productivos.

---
