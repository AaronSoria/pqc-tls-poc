#!/bin/bash

./bench_gpu > results_gpu.txt
grep '^CSV,' results_gpu.txt > results_gpu.csv