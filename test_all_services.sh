#!/usr/bin/env bash
set -euo pipefail

HOST="${1:-127.0.0.1}"

CLASSICAL_PORT=8443
OQS_PORT=9443
AWS_PQ_PORT=10443

OPENSSL_OQS_BIN="/opt/pqc-lab/openssl-oqs/bin/openssl"
S2NC_BIN="/opt/pqc-lab/build/s2n-tls/bin/s2nc"

export LD_LIBRARY_PATH="/opt/pqc-lab/liboqs/lib64:/opt/pqc-lab/liboqs/lib:/opt/pqc-lab/openssl-oqs/lib64:/opt/pqc-lab/openssl-oqs/lib:/opt/pqc-lab/build/aws-lc/crypto:/opt/pqc-lab/build/aws-lc:${LD_LIBRARY_PATH:-}"
export OPENSSL_MODULES="/opt/pqc-lab/oqs-provider/lib64/ossl-modules:/opt/pqc-lab/oqs-provider/lib/ossl-modules"

echo "========================================"
echo "Testing TLS services on host: ${HOST}"
echo "========================================"
echo

test_port() {
  local name="$1"
  local port="$2"

  echo "[PORT CHECK] ${name} (${HOST}:${port})"
  if nc -zv "${HOST}" "${port}" >/dev/null 2>&1; then
    echo "  OK: port is open"
  else
    echo "  FAIL: port is closed or unreachable"
  fi
  echo
}

measure_command() {
  local name="$1"
  shift

  echo "[HANDSHAKE TEST] ${name}"
  local start end elapsed

  start=$(python3 - <<'PY'
import time
print(time.perf_counter())
PY
)

  if "$@" >/dev/null 2>&1; then
    end=$(python3 - <<'PY'
import time
print(time.perf_counter())
PY
)
    elapsed=$(python3 - <<PY
start = float("${start}")
end = float("${end}")
print(round((end - start) * 1000, 3))
PY
)
    echo "  OK: handshake completed in ${elapsed} ms"
  else
    echo "  FAIL: handshake failed"
  fi
  echo
}

echo "1) Checking ports..."
test_port "Classical TLS" "${CLASSICAL_PORT}"
test_port "OQS Hybrid TLS" "${OQS_PORT}"
test_port "AWS PQ TLS" "${AWS_PQ_PORT}"

echo "2) Running handshake tests..."

measure_command \
  "Classical TLS (OpenSSL)" \
  sh -c "echo | openssl s_client -connect ${HOST}:${CLASSICAL_PORT} -quiet"

measure_command \
  "OQS Hybrid TLS (OpenSSL + oqs-provider)" \
  sh -c "echo | ${OPENSSL_OQS_BIN} s_client -connect ${HOST}:${OQS_PORT} -provider default -provider oqsprovider -groups X25519MLKEM768 -quiet"

measure_command \
  "AWS PQ TLS (s2n-tls + AWS-LC)" \
  sh -c "echo | ${S2NC_BIN} --insecure --ciphers default_pq ${HOST} ${AWS_PQ_PORT}"

echo "3) Done."