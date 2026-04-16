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

CMD ["bash"]