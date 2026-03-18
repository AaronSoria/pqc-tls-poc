FROM ubuntu:22.04

RUN apt-get update && apt-get install -y \
    build-essential \
    cmake \
    git \
    ninja-build \
    perl \
    python3 \
    ca-certificates \
    wget

WORKDIR /opt

# 1. OpenSSL
RUN git clone --depth=1 https://github.com/openssl/openssl.git
WORKDIR /opt/openssl
RUN ./Configure --prefix=/usr/local --openssldir=/usr/local/ssl --libdir=lib && \
    make -j$(nproc) && \
    make install && \
    make install_dev

RUN echo "/usr/local/lib" > /etc/ld.so.conf.d/openssl-local.conf && ldconfig

ENV LD_LIBRARY_PATH=/usr/local/lib
ENV PATH=/usr/local/bin:$PATH
ENV CMAKE_PREFIX_PATH=/usr/local
ENV OPENSSL_MODULES=/usr/local/lib/ossl-modules

# 2. liboqs
WORKDIR /opt
RUN git clone --depth=1 https://github.com/open-quantum-safe/liboqs.git
WORKDIR /opt/liboqs
RUN cmake -S . -B build -GNinja \
    -DOQS_BUILD_ONLY_LIB=ON \
    -DBUILD_SHARED_LIBS=ON \
    -DCMAKE_INSTALL_PREFIX=/usr/local \
    -DOPENSSL_ROOT_DIR=/usr/local \
    -DOPENSSL_INCLUDE_DIR=/usr/local/include \
    -DOPENSSL_CRYPTO_LIBRARY=/usr/local/lib/libcrypto.so \
    -DOPENSSL_SSL_LIBRARY=/usr/local/lib/libssl.so && \
    cmake --build build && \
    cmake --install build

# 3. oqs-provider
WORKDIR /opt
RUN git clone --depth=1 https://github.com/open-quantum-safe/oqs-provider.git
WORKDIR /opt/oqs-provider
RUN cmake -S . -B build -GNinja \
    -DCMAKE_INSTALL_PREFIX=/usr/local \
    -Dliboqs_DIR=/usr/local/lib/cmake/liboqs \
    -DOPENSSL_ROOT_DIR=/usr/local \
    -DOPENSSL_INCLUDE_DIR=/usr/local/include \
    -DOPENSSL_CRYPTO_LIBRARY=/usr/local/lib/libcrypto.so \
    -DOPENSSL_SSL_LIBRARY=/usr/local/lib/libssl.so \
    -DOPENSSL_USE_STATIC_LIBS=FALSE \
    -DCMAKE_PREFIX_PATH=/usr/local && \
    cmake --build build && \
    cmake --install build

# Verify the provider .so landed correctly
RUN ls /usr/local/lib/ossl-modules/oqsprovider.so && ldconfig

# 4. Config OpenSSL
RUN printf '%s\n' \
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
    > /usr/local/ssl/openssl.cnf

ENV OPENSSL_CONF=/usr/local/ssl/openssl.cnf

# Sanity check: providers and X25519MLKEM768 must be visible at build time
# RUN openssl list -providers | grep oqsprovider
# RUN openssl list -kem-algorithms

WORKDIR /app

CMD ["/usr/local/bin/openssl", "s_server", \
    "-cert", "cert.pem", \
    "-key", "key.pem", \
    "-accept", "9443", \
    "-provider", "default", \
    "-provider", "oqsprovider", \
    "-groups", "X25519MLKEM768", \
    "-www", \
    "-ign_eof"]