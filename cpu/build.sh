#!/bin/bash

git clone https://github.com/open-quantum-safe/liboqs.git
cd liboqs
mkdir build && cd build

cmake -GNinja .. \
  -DCMAKE_BUILD_TYPE=Release \
  -DOQS_USE_CUPQC=OFF \
  -DOQS_MINIMAL_BUILD="KEM_ml_kem_768"

ninja