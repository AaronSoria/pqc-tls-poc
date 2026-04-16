# 🔐 Benchmark TLS con PQC (AWS + s2n-tls + AWS-LC)

## 📌 Descripción General

Este proyecto implementa un **entorno de benchmarking** para comparar:

* TLS clásico (OpenSSL)
* TLS post-cuántico (Híbrido: X25519 + ML-KEM usando AWS-LC)

El objetivo es medir:

* Latencia del handshake
* Sobrecoste criptográfico
* Tamaño del handshake (bytes de entrada/salida)

Todos los experimentos se ejecutan en un **entorno controlado (AWS EC2)** para garantizar reproducibilidad.

---

## 🧱 Arquitectura

```text
Cliente (s2nc / openssl)
        ↓
   Handshake TLS
        ↓
Servidor (s2nd)
        ↓
AWS-LC (backend criptográfico con soporte PQ)
```

---

## ⚙️ Configuración del Entorno

### 1. Crear instancia EC2

* Tipo de instancia: `t2.micro` (Free Tier)
* Sistema operativo: **Ubuntu Server 22.04 LTS**
* Almacenamiento: 30 GB (gp3)
* Grupo de seguridad:

  * Permitir SSH (puerto 22)
  * Permitir TCP (puerto 8443)

---

### 2. Conexión por SSH

```bash
ssh -i your-key.pem ubuntu@<EC2_PUBLIC_IP>
```

---

## 🛠️ Instalación de dependencias

```bash
sudo apt update
sudo apt install -y build-essential cmake git golang
```

---

## 🔐 Compilación de AWS-LC (backend criptográfico)

```bash
git clone https://github.com/aws/aws-lc.git
cd aws-lc

cmake -B build
cmake --build build -j
sudo cmake --install build
```

Verificación:

```bash
strings /usr/local/lib/libcrypto.so | grep AWS-LC
```

---

## 🔐 Compilación de s2n-tls con AWS-LC

```bash
cd ~

git clone https://github.com/aws/s2n-tls.git
cd s2n-tls

cmake . -B build \
  -DCMAKE_PREFIX_PATH=/usr/local \
  -DS2N_NO_PQ=OFF

cmake --build build -j
```

---

## 🔑 Generación de certificados autofirmados

```bash
openssl req -x509 -newkey rsa:2048 \
  -keyout key.pem \
  -out cert.pem \
  -days 30 \
  -nodes \
  -subj "/CN=localhost"
```

---

## 🚀 Ejecución del servidor TLS con PQC

```bash
~/s2n-tls/build/bin/s2nd \
  --cert cert.pem \
  --key key.pem \
  --ciphers default_pq \
  0.0.0.0 8443
```

Salida esperada:

```text
libcrypto: AWS-LC
Listening on 0.0.0.0:8443
```

---

## 🔌 Prueba de conexión

### Cliente PQC

```bash
~/s2n-tls/build/bin/s2nc \
  --ciphers default_pq \
  --insecure \
  127.0.0.1 8443
```

Salida esperada:

```text
KEM Group: X25519MLKEM768 (PQ key exchange enabled)
Cipher negotiated: TLS_AES_128_GCM_SHA256
```

---

### TLS clásico (OpenSSL)

```bash
openssl s_client -connect 127.0.0.1:8443 -tls1_3
```

---

## ▶️ Ejecución del benchmark

```bash
python3 benchmark_tls.py
```

---

## 📈 Resultados de ejemplo

```text
Classical TLS   ≈ 2.6 ms
PQC TLS         ≈ 95 ms
Overhead        ≈ +93 ms

Handshake Size:
Bytes In  ≈ 2409
Bytes Out ≈ 1572
```

---

## 🧠 Hallazgos clave

* PQC introduce un **sobrecoste significativo en handshakes en frío (cold start)**
* Aumento del tamaño del handshake debido al intercambio de claves post-cuánticas (KEM)
* Los resultados son consistentes con el diseño híbrido de TLS post-cuántico

---

## ⚠️ Notas importantes

* Las mediciones deben ejecutarse **dentro de EC2 (localhost)** para evitar sesgos de red
* Los certificados autofirmados requieren el uso de `--insecure`
* Este entorno es **solo para benchmarking**, no para uso en producción

---

## 🚀 Trabajo futuro

* Integración con TLS gestionado por AWS (CloudFront / ALB)
* Comparación con implementaciones PQC de NVIDIA
* Medición del impacto de reutilización de sesiones TLS
* Incorporación de dashboards automatizados

---

## 📚 Referencias

* https://github.com/aws/s2n-tls
* https://github.com/aws/aws-lc
* https://aws.amazon.com/blogs/security/post-quantum-tls-now-supported/

---

## 👤 Autor

Luis Aaron Maximiliano Soria
Máster en Computación Cuántica – UNIR



56795.13
56795.13