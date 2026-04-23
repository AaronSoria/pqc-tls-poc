FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive
ARG GO_VERSION=1.22.12

RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    ninja-build \
    git \
    clang \
    perl \
    ca-certificates \
    curl \
    openssl \
    netcat-openbsd \
    && rm -rf /var/lib/apt/lists/*

# Go
RUN curl -L "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" -o /tmp/go.tar.gz && \
    rm -rf /usr/local/go && \
    tar -C /usr/local -xzf /tmp/go.tar.gz && \
    rm -f /tmp/go.tar.gz

ENV PATH="/usr/local/go/bin:${PATH}"

WORKDIR /opt

# AWS-LC (crypto backend para s2n)
RUN git clone https://github.com/aws/aws-lc.git && \
    cd aws-lc && \
    mkdir build && cd build && \
    cmake -GNinja \
        -DCMAKE_BUILD_TYPE=Release \
        -DBUILD_SHARED_LIBS=ON \
        .. && \
    ninja && \
    ninja install && \
    ldconfig

# s2n-tls compilado contra AWS-LC con PQ habilitado
RUN git clone https://github.com/aws/s2n-tls.git && \
    cd s2n-tls && \
    mkdir build && cd build && \
    cmake -GNinja \
        -DCMAKE_BUILD_TYPE=Release \
        -DS2N_LIBCRYPTO=aws-lc \
        -DS2N_NO_PQ=0 \
        -DBUILD_SHARED_LIBS=ON \
        -Dcrypto_INCLUDE_DIR=/opt/aws-lc/include \
        -Dcrypto_LIBRARY=/opt/aws-lc/build/crypto/libcrypto.so \
        .. && \
    ninja && \
    ninja install && \
    cp bin/s2nc /usr/local/bin/s2nc && \
    ldconfig

# OpenSSL con oqs-provider (para el cliente OQS)
RUN git clone --depth=1 https://github.com/openssl/openssl.git /opt/openssl && \
    cd /opt/openssl && \
    ./Configure --prefix=/usr/local/oqs-openssl --openssldir=/usr/local/oqs-openssl/ssl --libdir=lib && \
    make -j$(nproc) && \
    make install

RUN git clone --depth=1 https://github.com/open-quantum-safe/liboqs.git /opt/liboqs && \
    cmake -S /opt/liboqs -B /opt/liboqs/build -GNinja \
        -DOQS_BUILD_ONLY_LIB=ON \
        -DBUILD_SHARED_LIBS=ON \
        -DCMAKE_INSTALL_PREFIX=/usr/local/oqs-openssl \
        -DOPENSSL_ROOT_DIR=/usr/local/oqs-openssl && \
    cmake --build /opt/liboqs/build && \
    cmake --install /opt/liboqs/build

RUN git clone --depth=1 https://github.com/open-quantum-safe/oqs-provider.git /opt/oqs-provider && \
    cmake -S /opt/oqs-provider -B /opt/oqs-provider/build -GNinja \
        -DCMAKE_INSTALL_PREFIX=/usr/local/oqs-openssl \
        -Dliboqs_DIR=/usr/local/oqs-openssl/lib/cmake/liboqs \
        -DOPENSSL_ROOT_DIR=/usr/local/oqs-openssl && \
    cmake --build /opt/oqs-provider/build && \
    cmake --install /opt/oqs-provider/build

# Config openssl para oqsprovider
RUN printf '[openssl_init]\nproviders = provider_sect\n\n[provider_sect]\ndefault = default_sect\noqsprovider = oqsprovider_sect\n\n[default_sect]\nactivate = 1\n\n[oqsprovider_sect]\nactivate = 1\n' \
    > /usr/local/oqs-openssl/ssl/openssl.cnf && \
    echo 'openssl_conf = openssl_init' | cat - /usr/local/oqs-openssl/ssl/openssl.cnf > /tmp/cnf && \
    mv /tmp/cnf /usr/local/oqs-openssl/ssl/openssl.cnf

ENV OPENSSL_CONF=/usr/local/oqs-openssl/ssl/openssl.cnf
ENV LD_LIBRARY_PATH=/usr/local/oqs-openssl/lib:/usr/local/lib:$LD_LIBRARY_PATH
ENV PATH=/usr/local/oqs-openssl/bin:$PATH

# Build del benchmark Go con CGO
WORKDIR /app/benchmark-go
COPY benchmark-go/ .

RUN CGO_ENABLED=1 \
    CGO_CFLAGS="-I/opt/s2n-tls/api -I/opt/aws-lc/include" \
    CGO_LDFLAGS="-L/opt/s2n-tls/build/lib -ls2n -L/opt/aws-lc/build/crypto -lcrypto -lpthread -ldl -lm" \
    go build -o /usr/local/bin/benchmark ./cmd/benchmark/

CMD ["/usr/local/bin/benchmark"]
