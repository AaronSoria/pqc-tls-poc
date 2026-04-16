#!/usr/bin/env bash
set -euo pipefail

HOST="${1:-127.0.0.1}"
ITERATIONS="${2:-5}"

CLASSICAL_PORT=8443
OQS_PORT=9443
AWS_PQ_PORT=10443

OPENSSL_OQS_BIN="/opt/pqc-lab/openssl-oqs/bin/openssl"
S2NC_BIN="/opt/pqc-lab/build/s2n-tls/bin/s2nc"

export LD_LIBRARY_PATH="/opt/pqc-lab/liboqs/lib64:/opt/pqc-lab/liboqs/lib:/opt/pqc-lab/openssl-oqs/lib64:/opt/pqc-lab/openssl-oqs/lib:/opt/pqc-lab/build/aws-lc/crypto:/opt/pqc-lab/build/aws-lc:${LD_LIBRARY_PATH:-}"
export OPENSSL_MODULES="/opt/pqc-lab/oqs-provider/lib64/ossl-modules:/opt/pqc-lab/oqs-provider/lib/ossl-modules"

run_test() {
  local name="$1"
  local cmd="$2"
  local total=0
  local success=0

  echo "========================================"
  echo "Benchmarking: ${name}"
  echo "========================================"

  for i in $(seq 1 "${ITERATIONS}"); do
    start=$(python3 - <<'PY'
import time
print(time.perf_counter())
PY
)

    if eval "${cmd}" >/dev/null 2>&1; then
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
      echo "Run ${i}: ${elapsed} ms"
      total=$(python3 - <<PY
print(${total} + ${elapsed})
PY
)
      success=$((success + 1))
    else
      echo "Run ${i}: FAIL"
    fi
  done

  if [ "${success}" -gt 0 ]; then
    avg=$(python3 - <<PY
print(round(${total} / ${success}, 3))
PY
)
    echo "Average: ${avg} ms (${success}/${ITERATIONS} successful)"
  else
    echo "All runs failed"
  fi

  echo
}

run_test \
  "Classical TLS" \
  "echo | openssl s_client -connect ${HOST}:${CLASSICAL_PORT} -quiet"

run_test \
  "OQS Hybrid TLS" \
  "echo | ${OPENSSL_OQS_BIN} s_client -connect ${HOST}:${OQS_PORT} -provider default -provider oqsprovider -groups X25519MLKEM768 -quiet"

run_test \
  "AWS PQ TLS" \
  "echo | ${S2NC_BIN} --insecure --ciphers default_pq ${HOST} ${AWS_PQ_PORT}"