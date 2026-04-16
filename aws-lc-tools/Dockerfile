FROM ubuntu:22.04

ENV DEBIAN_FRONTEND=noninteractive

RUN apt-get update && apt-get install -y \
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

RUN git clone https://github.com/aws/aws-lc.git && \
    cd aws-lc && \
    mkdir build && cd build && \
    cmake -GNinja .. && \
    ninja

CMD ["bash"]