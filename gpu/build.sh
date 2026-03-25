#!/bin/bash

nvcc -std=c++17 -O3 -arch=sm_86 \
  -I/usr/local/cupqc-sdk/include \
  -I/usr/local/cupqc-sdk/include/cupqc \
  -L/usr/local/cupqc-sdk/lib -lcupqc-pk \
  bench_mlkem_gpu.cu -o bench_gpu