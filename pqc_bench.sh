#!/bin/bash
# =============================================================================
# pqc_bench.sh - PQC TLS Benchmark Bare Metal
# Ubuntu 22.04 LTS | RTX 3090 (Ampere sm_86)
#
# Compara tres stacks TLS + primitivas criptograficas en CPU y GPU:
#
#   Stack TLS:
#     1. Classical TLS  - OpenSSL del sistema (RSA-2048)
#     2. OQS PQC TLS    - OpenSSL + liboqs + oqs-provider (X25519MLKEM768)
#     3. AWS PQ TLS     - s2n-tls + AWS-LC (X25519MLKEM768)
#
#   Primitivas:
#     4. CPU            - liboqs speed_kem ML-KEM-768
#     5. GPU            - cuPQC ML-KEM-768 (requiere SDK NVIDIA)
#
# Uso:
#   sudo bash pqc_bench.sh            # setup completo + benchmark
#   sudo bash pqc_bench.sh --run-only # solo ejecutar (ya compilado)
#   sudo bash pqc_bench.sh --gpu-only # compilar/correr solo GPU (post-SDK)
#   sudo bash pqc_bench.sh --reset    # borrar estado de fases y recompilar todo
#
# Nota: La primera ejecucion puede tardar 30-60 min compilando dependencias.
#       Las siguientes son instantaneas (fase tracking).
# =============================================================================

set -euo pipefail

# Directorios
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Paths que coinciden con los CGO hardcodeados en benchmark-go/internal/awspq/awspq.go
# No cambiar sin actualizar tambien el codigo Go.
AWSLC_DIR=/opt/aws-lc
S2N_DIR=/opt/s2n-tls
OQS_PREFIX=/opt/oqs-openssl
LIBOQS_BENCH_DIR=/opt/liboqs-bench

GO_VERSION=1.22.12
CUDA_PKG=cuda-12-6
GPU_ARCH=sm_86
CUPQC_SDK=/usr/local/cupqc-sdk
BIN=/usr/local/bin

CERTS_DIR="$SCRIPT_DIR/certs"

CLASSICAL_PORT=8443
OQS_PORT=9443
AWS_PQ_PORT=10443

ITERATIONS=50

RESULTS_DIR="$SCRIPT_DIR/results/bare_metal_$(date +%Y%m%d_%H%M%S)"
PHASES_FILE="$SCRIPT_DIR/.pqc_phases"

# Colores
R='\033[0;31m' G='\033[0;32m' Y='\033[1;33m' B='\033[0;34m' C='\033[0;36m' N='\033[0m'
log()   { echo -e "${G}[OK]${N} $*"; }
warn()  { echo -e "${Y}[!!]${N} $*"; }
err()   { echo -e "${R}[XX]${N} $*" >&2; exit 1; }
info()  { echo -e "${C}[->]${N} $*"; }
phase() {
    echo -e "\n${B}==================================================${N}"
    echo -e "${B}  $*${N}"
    echo -e "${B}==================================================${N}\n"
}

# Phase tracking
is_done()   { [[ -f "$PHASES_FILE" ]] && grep -qx "$1" "$PHASES_FILE"; }
mark_done() { echo "$1" >> "$PHASES_FILE"; }

# Verificar root
[[ $EUID -ne 0 ]] && err "Ejecutar como root: sudo bash pqc_bench.sh"

# PIDs de servidores
SERVER_PIDS=()

cleanup() {
    if [[ ${#SERVER_PIDS[@]} -gt 0 ]]; then
        info "Deteniendo servidores TLS..."
        kill "${SERVER_PIDS[@]}" 2>/dev/null || true
        SERVER_PIDS=()
    fi
}
trap cleanup EXIT INT TERM

# =============================================================================
# FASE 0 - Dependencias del sistema
# =============================================================================
phase_sys_deps() {
    phase "Fase 0 - Dependencias del sistema"
    is_done sys_deps && { log "Ya instaladas, saltando"; return; }

    apt-get update -qq
    apt-get install -y \
        build-essential cmake ninja-build git clang perl python3 \
        ca-certificates curl wget bc netcat-openbsd lsof \
        pkg-config libssl-dev linux-headers-$(uname -r)

    mark_done sys_deps
    log "Dependencias instaladas"
}

# =============================================================================
# FASE 1 - NVIDIA Driver + CUDA
# =============================================================================
phase_cuda() {
    phase "Fase 1 - NVIDIA Driver + CUDA ${CUDA_PKG}"
    is_done cuda && {
        export PATH="/usr/local/cuda-12.6/bin:/usr/local/cuda/bin:$PATH"
        export LD_LIBRARY_PATH="/usr/local/cuda-12.6/lib64:/usr/local/cuda/lib64:${LD_LIBRARY_PATH:-}"
        log "CUDA ya instalado, saltando"
        return
    }

    if nvidia-smi &>/dev/null; then
        log "Driver NVIDIA activo:"
        nvidia-smi --query-gpu=name,driver_version,memory.total --format=csv,noheader
        export PATH="/usr/local/cuda-12.6/bin:/usr/local/cuda/bin:$PATH"
        export LD_LIBRARY_PATH="/usr/local/cuda-12.6/lib64:/usr/local/cuda/lib64:${LD_LIBRARY_PATH:-}"
        if ! command -v nvcc &>/dev/null; then
            warn "nvcc no encontrado - instalando CUDA toolkit..."
            apt-get install -y "$CUDA_PKG" 2>/dev/null || true
        fi
        nvcc --version | head -1
        mark_done cuda
        return
    fi

    info "Descargando repositorio CUDA para Ubuntu 22.04..."
    wget -q -O /tmp/cuda-keyring.deb \
        "https://developer.download.nvidia.com/compute/cuda/repos/ubuntu2204/x86_64/cuda-keyring_1.1-1_all.deb"
    dpkg -i /tmp/cuda-keyring.deb
    apt-get update -qq
    apt-get install -y "$CUDA_PKG"
    mark_done cuda

    echo ""
    warn "Driver NVIDIA instalado. REINICIO NECESARIO."
    warn "  1. sudo reboot"
    warn "  2. sudo bash pqc_bench.sh   (retoma desde Fase 2)"
    exit 0
}

# =============================================================================
# FASE 2 - Go toolchain
# =============================================================================
phase_go() {
    phase "Fase 2 - Go ${GO_VERSION}"
    is_done go && {
        export PATH="/usr/local/go/bin:$PATH"
        log "Go ya instalado"
        return
    }

    wget -q -O /tmp/go.tar.gz "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz"
    rm -rf /usr/local/go
    tar -C /usr/local -xzf /tmp/go.tar.gz
    rm -f /tmp/go.tar.gz
    export PATH="/usr/local/go/bin:$PATH"
    echo 'export PATH="/usr/local/go/bin:$PATH"' > /etc/profile.d/go.sh

    go version
    mark_done go
    log "Go instalado"
}

# =============================================================================
# FASE 3 - AWS-LC (en /opt/aws-lc, estatico)
# Rutas CGO hardcodeadas en awspq.go:
#   /opt/aws-lc/include
#   /opt/aws-lc/build/crypto/libcrypto.a
# =============================================================================
phase_awslc() {
    phase "Fase 3 - AWS-LC (estatico)"
    is_done awslc && { log "AWS-LC ya compilado, saltando"; return; }

    rm -rf "$AWSLC_DIR"
    git clone --depth=1 https://github.com/aws/aws-lc.git "$AWSLC_DIR"
    cd "$AWSLC_DIR"
    mkdir build && cd build
    cmake -GNinja \
        -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_SHARED_LIBS=OFF \
        ..
    ninja -j$(nproc)

    mark_done awslc
    log "AWS-LC compilado -> $AWSLC_DIR/build/crypto/libcrypto.a"
}

# =============================================================================
# FASE 4 - s2n-tls (en /opt/s2n-tls, contra AWS-LC, PQ habilitado)
# Rutas CGO hardcodeadas en awspq.go:
#   /opt/s2n-tls/api
#   /opt/s2n-tls/build/lib/libs2n.a
# =============================================================================
phase_s2n() {
    phase "Fase 4 - s2n-tls + AWS-LC (X25519MLKEM768)"
    is_done s2n && {
        log "s2n-tls ya compilado, saltando"
        ln -sf "$S2N_DIR/build/bin/s2nd" "$BIN/s2nd" 2>/dev/null || true
        ln -sf "$S2N_DIR/build/bin/s2nc" "$BIN/s2nc" 2>/dev/null || true
        return
    }

    rm -rf "$S2N_DIR"
    git clone --depth=1 https://github.com/aws/s2n-tls.git "$S2N_DIR"
    cd "$S2N_DIR"
    mkdir build && cd build
    cmake -GNinja \
        -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_SHARED_LIBS=OFF \
        -DS2N_LIBCRYPTO=aws-lc \
        -DS2N_NO_PQ=0 \
        -Dcrypto_INCLUDE_DIR="$AWSLC_DIR/include" \
        -Dcrypto_LIBRARY="$AWSLC_DIR/build/crypto/libcrypto.a" \
        ..
    ninja -j$(nproc)

    ln -sf "$S2N_DIR/build/bin/s2nd" "$BIN/s2nd"
    ln -sf "$S2N_DIR/build/bin/s2nc" "$BIN/s2nc"

    mark_done s2n
    log "s2n-tls compilado -> s2nd en $BIN/"
}

# =============================================================================
# FASE 5 - OpenSSL + liboqs + oqs-provider (prefijo aislado /opt/oqs-openssl)
# =============================================================================
phase_oqs_stack() {
    phase "Fase 5 - OpenSSL + liboqs + oqs-provider (aislado en $OQS_PREFIX)"
    is_done oqs_stack && { log "OQS stack ya compilado, saltando"; return; }

    # OpenSSL
    if [[ ! -f "$OQS_PREFIX/bin/openssl" ]]; then
        info "Compilando OpenSSL..."
        cd /tmp
        rm -rf openssl_src
        git clone --depth=1 https://github.com/openssl/openssl.git openssl_src
        cd openssl_src
        ./Configure \
            --prefix="$OQS_PREFIX" \
            --openssldir="$OQS_PREFIX/ssl" \
            --libdir=lib
        make -j$(nproc)
        make install
        make install_dev
        log "OpenSSL compilado"
    fi

    echo "/opt/oqs-openssl/lib" > /etc/ld.so.conf.d/oqs-openssl.conf
    ldconfig

    # liboqs
    if [[ ! -f "$OQS_PREFIX/lib/cmake/liboqs/liboqsConfig.cmake" ]]; then
        info "Compilando liboqs..."
        cd /tmp
        rm -rf liboqs_src
        git clone --depth=1 https://github.com/open-quantum-safe/liboqs.git liboqs_src
        cmake -S liboqs_src -B liboqs_src/build -GNinja \
            -DOQS_BUILD_ONLY_LIB=ON \
            -DBUILD_SHARED_LIBS=ON \
            -DCMAKE_INSTALL_PREFIX="$OQS_PREFIX" \
            -DOPENSSL_ROOT_DIR="$OQS_PREFIX" \
            -DOPENSSL_INCLUDE_DIR="$OQS_PREFIX/include" \
            -DOPENSSL_CRYPTO_LIBRARY="$OQS_PREFIX/lib/libcrypto.so" \
            -DOPENSSL_SSL_LIBRARY="$OQS_PREFIX/lib/libssl.so"
        cmake --build liboqs_src/build -j$(nproc)
        cmake --install liboqs_src/build
        ldconfig
        log "liboqs compilado"
    fi

    # oqs-provider
    if [[ ! -f "$OQS_PREFIX/lib/ossl-modules/oqsprovider.so" ]]; then
        info "Compilando oqs-provider..."
        cd /tmp
        rm -rf oqs_provider_src
        git clone --depth=1 https://github.com/open-quantum-safe/oqs-provider.git oqs_provider_src
        cmake -S oqs_provider_src -B oqs_provider_src/build -GNinja \
            -DCMAKE_INSTALL_PREFIX="$OQS_PREFIX" \
            -Dliboqs_DIR="$OQS_PREFIX/lib/cmake/liboqs" \
            -DOPENSSL_ROOT_DIR="$OQS_PREFIX" \
            -DOPENSSL_INCLUDE_DIR="$OQS_PREFIX/include" \
            -DOPENSSL_CRYPTO_LIBRARY="$OQS_PREFIX/lib/libcrypto.so" \
            -DOPENSSL_SSL_LIBRARY="$OQS_PREFIX/lib/libssl.so" \
            -DOPENSSL_USE_STATIC_LIBS=FALSE \
            -DCMAKE_PREFIX_PATH="$OQS_PREFIX"
        cmake --build oqs_provider_src/build -j$(nproc)
        cmake --install oqs_provider_src/build
        log "oqs-provider compilado"
    fi

    # openssl.cnf (sin heredoc para evitar problemas de transferencia)
    mkdir -p "$OQS_PREFIX/ssl"
    printf '%s\n' \
        'openssl_conf = openssl_init' \
        '' \
        '[openssl_init]' \
        'providers = provider_sect' \
        '' \
        '[provider_sect]' \
        'default = default_sect' \
        'oqsprovider = oqsprovider_sect' \
        '' \
        '[default_sect]' \
        'activate = 1' \
        '' \
        '[oqsprovider_sect]' \
        'activate = 1' \
        > "$OQS_PREFIX/ssl/openssl.cnf"

    # Verificacion
    info "Verificando X25519MLKEM768..."
    OPENSSL_CONF="$OQS_PREFIX/ssl/openssl.cnf" \
    OPENSSL_MODULES="$OQS_PREFIX/lib/ossl-modules" \
    LD_LIBRARY_PATH="$OQS_PREFIX/lib" \
    "$OQS_PREFIX/bin/openssl" list -kem-algorithms 2>/dev/null | grep -q "X25519MLKEM768" \
        || err "X25519MLKEM768 no disponible - revisar oqs-provider"

    mark_done oqs_stack
    log "OQS stack listo en $OQS_PREFIX"
}

# =============================================================================
# FASE 6 - liboqs standalone (speed_kem para benchmark CPU)
# =============================================================================
phase_liboqs_bench() {
    phase "Fase 6 - liboqs speed_kem (benchmark CPU)"
    is_done liboqs_bench && { log "liboqs bench ya compilado, saltando"; return; }

    rm -rf "$LIBOQS_BENCH_DIR"
    git clone --depth=1 https://github.com/open-quantum-safe/liboqs.git "$LIBOQS_BENCH_DIR"

    cmake -S "$LIBOQS_BENCH_DIR" -B "$LIBOQS_BENCH_DIR/build" -GNinja \
        -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_SHARED_LIBS=OFF \
        -DOQS_BUILD_ONLY_LIB=OFF \
        -DOQS_MINIMAL_BUILD="KEM_ml_kem_768"

    cmake --build "$LIBOQS_BENCH_DIR/build" -j$(nproc)

    SPEED_BIN=$(find "$LIBOQS_BENCH_DIR/build" -name "speed_kem" -type f 2>/dev/null | head -1)
    if [[ -n "${SPEED_BIN:-}" ]]; then
        cp "$SPEED_BIN" "$BIN/pqc-speed-kem"
        log "speed_kem -> $BIN/pqc-speed-kem"
    else
        warn "speed_kem no encontrado tras el build"
    fi

    mark_done liboqs_bench
}

# =============================================================================
# FASE 7 - Certificados TLS
# =============================================================================
phase_certs() {
    phase "Fase 7 - Certificados TLS"
    mkdir -p "$CERTS_DIR"

    if [[ ! -f "$CERTS_DIR/classical-cert.pem" ]]; then
        openssl req -x509 -newkey rsa:2048 \
            -keyout "$CERTS_DIR/classical-key.pem" \
            -out    "$CERTS_DIR/classical-cert.pem" \
            -nodes -days 365 -subj '/CN=localhost' 2>/dev/null
        log "Cert clasico generado"
    fi

    if [[ ! -f "$CERTS_DIR/oqs-cert.pem" ]]; then
        OPENSSL_CONF="$OQS_PREFIX/ssl/openssl.cnf" \
        OPENSSL_MODULES="$OQS_PREFIX/lib/ossl-modules" \
        LD_LIBRARY_PATH="$OQS_PREFIX/lib" \
        "$OQS_PREFIX/bin/openssl" req -x509 -newkey rsa:2048 \
            -keyout "$CERTS_DIR/oqs-key.pem" \
            -out    "$CERTS_DIR/oqs-cert.pem" \
            -nodes -days 365 -subj '/CN=localhost' 2>/dev/null
        log "Cert OQS generado"
    fi

    if [[ ! -f "$CERTS_DIR/aws-cert.pem" ]]; then
        openssl req -x509 -newkey rsa:2048 \
            -keyout "$CERTS_DIR/aws-key.pem" \
            -out    "$CERTS_DIR/aws-cert.pem" \
            -nodes -days 365 -subj '/CN=localhost' 2>/dev/null
        log "Cert AWS PQ generado"
    fi

    log "Certificados listos en $CERTS_DIR"
}

# =============================================================================
# FASE 8 - Build benchmark Go (CGO + s2n-tls + AWS-LC)
# =============================================================================
phase_build_go_bench() {
    phase "Fase 8 - Build benchmark Go (CGO)"
    is_done go_bench && { log "Benchmark Go ya compilado, saltando"; return; }

    export PATH="/usr/local/go/bin:$PATH"
    [[ -d "$SCRIPT_DIR/benchmark-go" ]] || err "No se encontro $SCRIPT_DIR/benchmark-go"

    cd "$SCRIPT_DIR/benchmark-go"

    CGO_ENABLED=1 \
    CGO_CFLAGS="-I$S2N_DIR/api -I$AWSLC_DIR/include" \
    CGO_LDFLAGS="-L$S2N_DIR/build/lib -ls2n -L$AWSLC_DIR/build/crypto -lcrypto -lpthread -ldl -lm" \
    go build -o "$BIN/pqc-benchmark" ./cmd/benchmark/

    mark_done go_bench
    log "pqc-benchmark -> $BIN/pqc-benchmark"
}

# =============================================================================
# FASE 9 - Build GPU benchmark (opcional - requiere SDK cuPQC de NVIDIA)
# =============================================================================
phase_build_gpu_bench() {
    phase "Fase 9 - Build GPU benchmark (cuPQC ML-KEM-768)"

    if [[ ! -d "$CUPQC_SDK" ]]; then
        warn "SDK cuPQC no encontrado en $CUPQC_SDK"
        echo "  Para habilitarlo:"
        echo "    1. Registrate en https://developer.nvidia.com/cupqc"
        echo "    2. Descarga el SDK y extraelo en $CUPQC_SDK"
        echo "       Debe existir: $CUPQC_SDK/include/pk.hpp"
        echo "    3. sudo bash pqc_bench.sh --gpu-only"
        return
    fi

    is_done gpu_bench && { log "GPU benchmark ya compilado, saltando"; return; }

    export PATH="/usr/local/cuda-12.6/bin:/usr/local/cuda/bin:$PATH"
    command -v nvcc &>/dev/null || err "nvcc no encontrado"

    # cuPQC usa device-side LTO (NVVM bitcode en la .a).
    # Pasar la ruta completa de la .a directamente en lugar de -L/-l
    # para que nvcc exponga el IR al device linker correctamente.
    local CUPQC_LIB
    CUPQC_LIB=$(find "$CUPQC_SDK/lib" -name "libcupqc-pk*.a" | head -1)
    [[ -z "$CUPQC_LIB" ]] && err "No se encontró libcupqc-pk*.a en $CUPQC_SDK/lib"

    # -rdc=true: Relocatable Device Code — permite externs de device no resueltos
    # durante compilación; nvlink los resuelve al linkear con la .a de cuPQC.
    # Funciona en CUDA 11.x y 12.x (más robusto que -dlto solo).
    nvcc -std=c++17 -O3 -rdc=true -dlto -arch="$GPU_ARCH" \
        -I"$CUPQC_SDK/include" \
        -I"$CUPQC_SDK/include/cupqc" \
        "$SCRIPT_DIR/gpu/bench_mlkem_gpu.cu" \
        "$CUPQC_LIB" \
        -o "$BIN/pqc-bench-gpu"

    mark_done gpu_bench
    log "pqc-bench-gpu -> $BIN/pqc-bench-gpu"
}

# =============================================================================
# RUN - Iniciar servidores TLS
# =============================================================================
start_servers() {
    phase "Iniciando servidores TLS"

    for port in $CLASSICAL_PORT $OQS_PORT $AWS_PQ_PORT; do
        if lsof -ti tcp:$port &>/dev/null; then
            warn "Puerto $port ocupado - liberando..."
            lsof -ti tcp:$port | xargs kill -9 2>/dev/null || true
            sleep 0.5
        fi
    done

    # Servidor 1: Classical TLS (RSA-2048)
    openssl s_server \
        -cert "$CERTS_DIR/classical-cert.pem" \
        -key  "$CERTS_DIR/classical-key.pem" \
        -accept $CLASSICAL_PORT \
        -www -ign_eof 2>/dev/null &
    SERVER_PIDS+=($!)
    log "Classical TLS server en :$CLASSICAL_PORT (PID ${SERVER_PIDS[-1]})"

    # Servidor 2: OQS PQC TLS (X25519MLKEM768)
    OPENSSL_CONF="$OQS_PREFIX/ssl/openssl.cnf" \
    OPENSSL_MODULES="$OQS_PREFIX/lib/ossl-modules" \
    LD_LIBRARY_PATH="$OQS_PREFIX/lib:${LD_LIBRARY_PATH:-}" \
    "$OQS_PREFIX/bin/openssl" s_server \
        -cert "$CERTS_DIR/oqs-cert.pem" \
        -key  "$CERTS_DIR/oqs-key.pem" \
        -accept $OQS_PORT \
        -provider default \
        -provider oqsprovider \
        -groups X25519MLKEM768 \
        -www -ign_eof 2>/dev/null &
    SERVER_PIDS+=($!)
    log "OQS PQC TLS server en :$OQS_PORT (PID ${SERVER_PIDS[-1]})"

    # Servidor 3: AWS PQ TLS (s2n-tls + AWS-LC)
    s2nd \
        --cert "$CERTS_DIR/aws-cert.pem" \
        --key  "$CERTS_DIR/aws-key.pem" \
        --ciphers default_pq \
        --parallelize \
        --self-service-blinding \
        0.0.0.0 $AWS_PQ_PORT 2>/dev/null &
    SERVER_PIDS+=($!)
    log "AWS PQ TLS server en :$AWS_PQ_PORT (PID ${SERVER_PIDS[-1]})"

    info "Esperando que los tres servidores esten listos..."
    for port in $CLASSICAL_PORT $OQS_PORT $AWS_PQ_PORT; do
        tries=0
        until nc -z localhost $port 2>/dev/null; do
            sleep 0.3
            tries=$((tries + 1))
            [[ $tries -gt 40 ]] && err "Servidor :$port no respondio tras 12s"
        done
        log "  :$port listo"
    done
}

# =============================================================================
# RUN - Benchmark TLS
# =============================================================================
run_tls_bench() {
    phase "Benchmark TLS - $ITERATIONS iteraciones por stack"
    mkdir -p "$RESULTS_DIR"

    PATH="$OQS_PREFIX/bin:/usr/local/go/bin:/usr/local/bin:$PATH" \
    OPENSSL_CONF="$OQS_PREFIX/ssl/openssl.cnf" \
    OPENSSL_MODULES="$OQS_PREFIX/lib/ossl-modules" \
    LD_LIBRARY_PATH="$OQS_PREFIX/lib:${LD_LIBRARY_PATH:-}" \
    CLASSICAL_HOST=localhost  CLASSICAL_PORT=$CLASSICAL_PORT \
    PQC_HOST=localhost        PQC_PORT=$OQS_PORT \
    AWS_PQ_HOST=localhost     AWS_PQ_PORT=$AWS_PQ_PORT \
    ITERATIONS=$ITERATIONS \
    pqc-benchmark 2>&1 | tee "$RESULTS_DIR/tls.txt"

    log "Resultados TLS -> $RESULTS_DIR/tls.txt"
}

# =============================================================================
# RUN - Benchmark CPU (primitivas ML-KEM-768)
# =============================================================================
run_cpu_bench() {
    phase "Benchmark CPU - ML-KEM-768 primitivas"
    mkdir -p "$RESULTS_DIR"

    if ! command -v pqc-speed-kem &>/dev/null; then
        warn "pqc-speed-kem no disponible, saltando CPU benchmark"
        return
    fi

    info "Midiendo keygen / encaps / decaps en CPU (~30s)..."
    pqc-speed-kem ML-KEM-768 2>&1 | tee "$RESULTS_DIR/cpu.txt"
    log "Resultados CPU -> $RESULTS_DIR/cpu.txt"
}

# =============================================================================
# RUN - Benchmark GPU (cuPQC, batch 1 a 8192)
# =============================================================================
run_gpu_bench() {
    phase "Benchmark GPU - ML-KEM-768 (cuPQC)"

    if ! command -v pqc-bench-gpu &>/dev/null; then
        warn "pqc-bench-gpu no disponible (SDK cuPQC no instalado)"
        return
    fi

    mkdir -p "$RESULTS_DIR"
    export PATH="/usr/local/cuda-12.6/bin:/usr/local/cuda/bin:$PATH"
    export LD_LIBRARY_PATH="/usr/local/cuda-12.6/lib64:/usr/local/cuda/lib64:${LD_LIBRARY_PATH:-}"
    [[ -d "$CUPQC_SDK/lib" ]] && export LD_LIBRARY_PATH="$CUPQC_SDK/lib:$LD_LIBRARY_PATH"

    info "GPU: $(nvidia-smi --query-gpu=name,memory.total --format=csv,noheader 2>/dev/null | head -1)"

    pqc-bench-gpu 2>&1 | tee "$RESULTS_DIR/gpu_raw.txt"
    grep '^CSV,' "$RESULTS_DIR/gpu_raw.txt" > "$RESULTS_DIR/gpu.csv" 2>/dev/null || true
    log "Resultados GPU -> $RESULTS_DIR/gpu.csv"
}

# =============================================================================
# Resumen final
# =============================================================================
print_summary() {
    echo ""
    echo -e "${B}=====================================================${N}"
    echo -e "${B}             RESULTADOS FINALES                      ${N}"
    echo -e "${B}=====================================================${N}"
    echo -e "${C}Directorio: $RESULTS_DIR${N}"
    echo ""

    if [[ -f "$RESULTS_DIR/tls.txt" ]]; then
        echo -e "${G}TLS Handshake (Classical vs OQS vs AWS PQ):${N}"
        cat "$RESULTS_DIR/tls.txt"
        echo ""
    fi

    if [[ -f "$RESULTS_DIR/cpu.txt" ]]; then
        echo -e "${G}CPU - ML-KEM-768 (keygen / encaps / decaps):${N}"
        grep -E "(keygen|encaps|decaps|ML-KEM|ops|us)" "$RESULTS_DIR/cpu.txt" 2>/dev/null \
            || cat "$RESULTS_DIR/cpu.txt"
        echo ""
    fi

    if [[ -f "$RESULTS_DIR/gpu.csv" ]] && [[ -s "$RESULTS_DIR/gpu.csv" ]]; then
        echo -e "${G}GPU - ML-KEM-768 cuPQC (us/op por batch size):${N}"
        printf "  %-8s  %-8s  %s\n" "batch" "op" "us/op"
        printf "  %-8s  %-8s  %s\n" "-----" "-------" "------"
        while IFS=, read -r _ batch op us; do
            printf "  %-8s  %-8s  %.4f\n" "$batch" "$op" "$us"
        done < "$RESULTS_DIR/gpu.csv"
        echo ""
    fi

    ls -lh "$RESULTS_DIR/" 2>/dev/null | awk 'NR>1 {print "  "$NF"  ("$5")"}'
    echo ""
}

# =============================================================================
# MAIN
# =============================================================================
main() {
    echo -e "${B}"
    echo "====================================================="
    echo "  PQC TLS Benchmark - Bare Metal"
    echo "  Ubuntu 22.04 LTS  |  RTX 3090 (Ampere sm_86)"
    echo "====================================================="
    echo -e "${N}"

    local mode="${1:-}"

    if [[ "$mode" == "--reset" ]]; then
        warn "Borrando estado de fases - se recompilara todo"
        rm -f "$PHASES_FILE"
        shift
        mode="${1:-}"
    fi

    if [[ "$mode" == "--gpu-only" ]]; then
        export PATH="/usr/local/cuda/bin:/usr/local/bin:$PATH"
        export LD_LIBRARY_PATH="/usr/local/cuda-12.6/lib64:/usr/local/cuda/lib64:${LD_LIBRARY_PATH:-}"
        phase_build_gpu_bench
        run_gpu_bench
        print_summary
        return
    fi

    if [[ "$mode" == "--run-only" ]]; then
        info "Modo --run-only: saltando build"
        export PATH="/usr/local/go/bin:/usr/local/bin:$PATH"
        phase_certs
        start_servers
        run_tls_bench
        cleanup
        run_cpu_bench
        run_gpu_bench
        print_summary
        return
    fi

    # Setup completo
    phase_sys_deps
    phase