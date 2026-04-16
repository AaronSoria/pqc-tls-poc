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
    && rm -rf /var/lib/apt/lists/*

RUN curl -L "https://go.dev/dl/go${GO_VERSION}.linux-amd64.tar.gz" -o /tmp/go.tar.gz && \
    rm -rf /usr/local/go && \
    tar -C /usr/local -xzf /tmp/go.tar.gz && \
    rm -f /tmp/go.tar.gz

ENV PATH="/usr/local/go/bin:${PATH}"

WORKDIR /opt

RUN git clone https://github.com/aws/aws-lc.git && \
    cd aws-lc && \
    mkdir build && cd build && \
    cmake -GNinja .. && \
    ninja

RUN git clone https://github.com/aws/s2n-tls.git && \
    cd s2n-tls && \
    mkdir build && cd build && \
    cmake -GNinja \
        -DCMAKE_BUILD_TYPE=Release \
        -DS2N_LIBCRYPTO=aws-lc \
        -DS2N_NO_PQ=0 \
        -Dcrypto_INCLUDE_DIR=/opt/aws-lc/include \
        -Dcrypto_LIBRARY=/opt/aws-lc/build/crypto/libcrypto.a \
        .. && \
    ninja

CMD ["bash"]