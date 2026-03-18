# Project: PQC TLS Benchmark

## Goal
This project implements a hybrid classical–post-quantum TLS benchmarking system.

## Architecture

- gateway/: handles routing and provider abstraction
- client/: simulates classical and PQC clients
- benchmark/: measures latency and performance

## Rules

- Do NOT change public interfaces unless explicitly requested
- Keep implementations simple and testable
- Avoid adding external dependencies unless necessary
- Prefer standard library
- Keep code modular and readable

## Providers

- OpenSSLOQSProvider: simulates PQC TLS
- AWSS2NProvider: classical TLS

## Benchmark Requirements

- Must measure:
  - handshake time
  - request latency
  - average over multiple runs

## Constraints

- This is a PoC, not production
- Focus on clarity over optimization

## Coding Style

- Python simple and explicit
- No unnecessary abstractions