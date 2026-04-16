#!/usr/bin/env bash
set -euo pipefail

BASE_DIR="/opt/pqc-lab"
SRC_DIR="${BASE_DIR}/src"
BUILD_DIR="${BASE_DIR}/build"
CERT_DIR="${BASE_DIR}/certs"
BIN_DIR="${BASE_DIR}/bin"
LOG_DIR="/var/log/pqc-lab"

OPENSSL_OQS_PREFIX="${BASE_DIR}/openssl-oqs"
LIBOQS_PREFIX="${BASE_DIR}/liboqs"
OQS_PROVIDER_PREFIX="${BASE_DIR}/oqs-provider"
AWSLC_BUILD_DIR="${BUILD_DIR}/aws-lc"
S2N_BUILD_DIR="${BUILD_DIR}/s2n-tls"

CLASSICAL_PORT=8443
OQS_PORT=9443
AWS_PQ_PORT=10443

OPENSSL_VERSION="openssl-3.2.2"

echo "[1/10] Installing system packages..."
sudo apt-get update
sudo apt-get install -y \
  build-essential \
  cmake \
  ninja-build \
  git \
  clang \
  pkg-config \
  python3 \
  python3-pip \
  golang \
  perl \
  ca-certificates \
  wget \
  curl \
  unzip \
  jq \
  netcat-openbsd \
  openssl \
  libssl-dev

echo "[2/10] Creating directories..."
sudo mkdir -p "${SRC_DIR}" "${BUILD_DIR}" "${CERT_DIR}" "${BIN_DIR}" "${LOG_DIR}"
sudo chown -R "$(whoami)":"$(whoami)" "${BASE_DIR}"

cd "${SRC_DIR}"

echo "[3/10] Downloading OpenSSL source for OQS build..."
if [ ! -d "${SRC_DIR}/${OPENSSL_VERSION}" ]; then
  wget "https://www.openssl.org/source/${OPENSSL_VERSION}.tar.gz"
  tar -xzf "${OPENSSL_VERSION}.tar.gz"
fi

echo "[4/10] Building liboqs..."
if [ ! -d "${SRC_DIR}/liboqs" ]; then
  git clone --branch main https://github.com/open-quantum-safe/liboqs.git
fi

cmake -S "${SRC_DIR}/liboqs" -B "${BUILD_DIR}/liboqs" \
  -GNinja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="${LIBOQS_PREFIX}" \
  -DOQS_BUILD_ONLY_LIB=ON
cmake --build "${BUILD_DIR}/liboqs"
cmake --install "${BUILD_DIR}/liboqs"

echo "[5/10] Building OpenSSL for OQS provider..."
cd "${SRC_DIR}/${OPENSSL_VERSION}"
./Configure linux-x86_64 \
  --prefix="${OPENSSL_OQS_PREFIX}" \
  --openssldir="${OPENSSL_OQS_PREFIX}/ssl" \
  shared
make -j"$(nproc)"
make install_sw

echo "[6/10] Building oqs-provider..."
cd "${SRC_DIR}"
if [ ! -d "${SRC_DIR}/oqs-provider" ]; then
  git clone --branch main https://github.com/open-quantum-safe/oqs-provider.git
fi

cmake -S "${SRC_DIR}/oqs-provider" -B "${BUILD_DIR}/oqs-provider" \
  -GNinja \
  -DCMAKE_BUILD_TYPE=Release \
  -DCMAKE_INSTALL_PREFIX="${OQS_PROVIDER_PREFIX}" \
  -DOPENSSL_ROOT_DIR="${OPENSSL_OQS_PREFIX}" \
  -Dliboqs_DIR="${BUILD_DIR}/liboqs"
cmake --build "${BUILD_DIR}/oqs-provider"
cmake --install "${BUILD_DIR}/oqs-provider"

echo "[7/10] Building AWS-LC..."
cd "${SRC_DIR}"
if [ ! -d "${SRC_DIR}/aws-lc" ]; then
  git clone https://github.com/aws/aws-lc.git
fi

cmake -S "${SRC_DIR}/aws-lc" -B "${AWSLC_BUILD_DIR}" \
  -GNinja \
  -DCMAKE_BUILD_TYPE=Release
cmake --build "${AWSLC_BUILD_DIR}"

echo "[8/10] Building s2n-tls against AWS-LC..."
cd "${SRC_DIR}"
if [ ! -d "${SRC_DIR}/s2n-tls" ]; then
  git clone https://github.com/aws/s2n-tls.git
fi

cmake -S "${SRC_DIR}/s2n-tls" -B "${S2N_BUILD_DIR}" \
  -GNinja \
  -DCMAKE_BUILD_TYPE=Release \
  -DS2N_LIBCRYPTO=aws-lc \
  -DS2N_NO_PQ=0 \
  -DAWSLC_DIR="${AWSLC_BUILD_DIR}"
cmake --build "${S2N_BUILD_DIR}"

echo "[9/10] Generating certificates..."
if [ ! -f "${CERT_DIR}/classical-cert.pem" ] || [ ! -f "${CERT_DIR}/classical-key.pem" ]; then
  openssl req -x509 -newkey rsa:2048 -nodes \
    -keyout "${CERT_DIR}/classical-key.pem" \
    -out "${CERT_DIR}/classical-cert.pem" \
    -days 7 \
    -subj "/CN=localhost"
fi

if [ ! -f "${CERT_DIR}/oqs-cert.pem" ] || [ ! -f "${CERT_DIR}/oqs-key.pem" ]; then
  openssl req -x509 -newkey rsa:2048 -nodes \
    -keyout "${CERT_DIR}/oqs-key.pem" \
    -out "${CERT_DIR}/oqs-cert.pem" \
    -days 7 \
    -subj "/CN=localhost"
fi

if [ ! -f "${CERT_DIR}/aws-pq-cert.pem" ] || [ ! -f "${CERT_DIR}/aws-pq-key.pem" ]; then
  openssl req -x509 -newkey rsa:2048 -nodes \
    -keyout "${CERT_DIR}/aws-pq-key.pem" \
    -out "${CERT_DIR}/aws-pq-cert.pem" \
    -days 7 \
    -subj "/CN=localhost"
fi

echo "[10/10] Creating launcher scripts..."

cat > "${BIN_DIR}/start-classical-server.sh" <<EOF
#!/usr/bin/env bash
exec openssl s_server \
  -cert "${CERT_DIR}/classical-cert.pem" \
  -key "${CERT_DIR}/classical-key.pem" \
  -accept ${CLASSICAL_PORT} \
  -www \
  -ign_eof
EOF

cat > "${BIN_DIR}/start-oqs-server.sh" <<EOF
#!/usr/bin/env bash
export LD_LIBRARY_PATH="${LIBOQS_PREFIX}/lib64:${LIBOQS_PREFIX}/lib:${OPENSSL_OQS_PREFIX}/lib64:${OPENSSL_OQS_PREFIX}/lib:\${LD_LIBRARY_PATH:-}"
export OPENSSL_MODULES="${OQS_PROVIDER_PREFIX}/lib64/ossl-modules:${OQS_PROVIDER_PREFIX}/lib/ossl-modules"
exec "${OPENSSL_OQS_PREFIX}/bin/openssl" s_server \
  -cert "${CERT_DIR}/oqs-cert.pem" \
  -key "${CERT_DIR}/oqs-key.pem" \
  -accept ${OQS_PORT} \
  -www \
  -provider default \
  -provider oqsprovider \
  -groups X25519MLKEM768 \
  -ign_eof
EOF

cat > "${BIN_DIR}/start-aws-pq-server.sh" <<EOF
#!/usr/bin/env bash
export LD_LIBRARY_PATH="${AWSLC_BUILD_DIR}/crypto:${AWSLC_BUILD_DIR}:\${LD_LIBRARY_PATH:-}"
exec "${S2N_BUILD_DIR}/bin/s2nd" default_pq ${AWS_PQ_PORT} \
  --cert "${CERT_DIR}/aws-pq-cert.pem" \
  --key "${CERT_DIR}/aws-pq-key.pem"
EOF

chmod +x "${BIN_DIR}/start-classical-server.sh"
chmod +x "${BIN_DIR}/start-oqs-server.sh"
chmod +x "${BIN_DIR}/start-aws-pq-server.sh"

echo "Creating systemd services..."

sudo tee /etc/systemd/system/classical-server.service > /dev/null <<EOF
[Unit]
Description=Classical TLS Server (OpenSSL)
After=network.target

[Service]
Type=simple
ExecStart=${BIN_DIR}/start-classical-server.sh
Restart=always
RestartSec=2
StandardOutput=append:${LOG_DIR}/classical-server.log
StandardError=append:${LOG_DIR}/classical-server.err

[Install]
WantedBy=multi-user.target
EOF

sudo tee /etc/systemd/system/oqs-server.service > /dev/null <<EOF
[Unit]
Description=OQS Hybrid TLS Server (OpenSSL + liboqs + oqs-provider)
After=network.target

[Service]
Type=simple
ExecStart=${BIN_DIR}/start-oqs-server.sh
Restart=always
RestartSec=2
StandardOutput=append:${LOG_DIR}/oqs-server.log
StandardError=append:${LOG_DIR}/oqs-server.err

[Install]
WantedBy=multi-user.target
EOF

sudo tee /etc/systemd/system/aws-pq-server.service > /dev/null <<EOF
[Unit]
Description=AWS PQ TLS Server (s2n-tls + AWS-LC)
After=network.target

[Service]
Type=simple
ExecStart=${BIN_DIR}/start-aws-pq-server.sh
Restart=always
RestartSec=2
StandardOutput=append:${LOG_DIR}/aws-pq-server.log
StandardError=append:${LOG_DIR}/aws-pq-server.err

[Install]
WantedBy=multi-user.target
EOF

sudo systemctl daemon-reload
sudo systemctl enable classical-server oqs-server aws-pq-server
sudo systemctl restart classical-server oqs-server aws-pq-server

echo
echo "Done."
echo "Check services with:"
echo "  systemctl status classical-server oqs-server aws-pq-server"
echo
echo "Ports:"
echo "  Classical TLS  : ${CLASSICAL_PORT}"
echo "  OQS Hybrid TLS : ${OQS_PORT}"
echo "  AWS PQ TLS     : ${AWS_PQ_PORT}"
echo
echo "Quick checks:"
echo "  nc -zv 127.0.0.1 ${CLASSICAL_PORT}"
echo "  nc -zv 127.0.0.1 ${OQS_PORT}"
echo "  nc -zv 127.0.0.1 ${AWS_PQ_PORT}"