FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
    python3 \
    python3-pip \
    openssl \
    netcat-openbsd \
    build-essential \
    cmake \
    ninja-build \
    git \
    clang \
    perl \
    golang \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /opt

# Build AWS-LC
RUN git clone https://github.com/aws/aws-lc.git && \
    cd aws-lc && \
    mkdir build && cd build && \
    cmake -GNinja .. && \
    ninja

# Build s2n-tls
RUN git clone https://github.com/aws/s2n-tls.git && \
    cd s2n-tls && \
    mkdir build && cd build && \
    cmake -GNinja \
      -DCMAKE_BUILD_TYPE=Release \
      -DS2N_LIBCRYPTO=aws-lc \
      -DS2N_NO_PQ=0 \
      -DAWSLC_DIR=/opt/aws-lc/build \
      .. && \
    ninja && \
    cp /opt/s2n-tls/build/bin/s2nc /usr/local/bin/s2nc

WORKDIR /app

COPY . /app

RUN pip3 install --no-cache-dir -r requirements.txt || true

CMD ["python3", "-m", "benchmark.run_benchmark"]