### EJECUTADO EN EC2


import subprocess
import time
import statistics

TARGET_HOST = "18.219.3.0"
PORT = "8443"
ITERATIONS = 10


def run_command(cmd):
    start = time.time()
    result = subprocess.run(
        cmd,
        shell=True,
        stdout=subprocess.PIPE,
        stderr=subprocess.STDOUT,
        text=True
    )
    end = time.time()

    latency_ms = (end - start) * 1000
    return latency_ms, result.stdout


def benchmark_classical():
    latencies = []

    for _ in range(ITERATIONS):
        cmd = f"echo | openssl s_client -connect {TARGET_HOST}:{PORT} -tls1_3 -ign_eof"
        latency, _ = run_command(cmd)
        latencies.append(latency)

    return latencies


def benchmark_pqc():
    latencies = []
    bytes_in = None
    bytes_out = None

    for _ in range(ITERATIONS):
        cmd = f"~/s2n-tls/build/bin/s2nc --ciphers default_pq --insecure {TARGET_HOST} {PORT}"
        latency, output = run_command(cmd)
        latencies.append(latency)

        for line in output.splitlines():
            if "Wire bytes in:" in line:
                bytes_in = int(line.split(":")[1].strip())
            if "Wire bytes out:" in line:
                bytes_out = int(line.split(":")[1].strip())

    return latencies, bytes_in, bytes_out


def summarize(name, latencies):
    print(f"\n{name}")
    print("-" * 40)
    print(f"Runs: {len(latencies)}")
    print(f"Avg latency: {statistics.mean(latencies):.2f} ms")
    print(f"Min latency: {min(latencies):.2f} ms")
    print(f"Max latency: {max(latencies):.2f} ms")


def main():
    print("Running TLS Benchmark...\n")

    classical = benchmark_classical()
    pqc, bytes_in, bytes_out = benchmark_pqc()

    summarize("Classical TLS", classical)
    summarize("PQC TLS (Hybrid)", pqc)

    print("\nHandshake Size (PQC)")
    print("-" * 40)
    print(f"Bytes In : {bytes_in}")
    print(f"Bytes Out: {bytes_out}")

    overhead = statistics.mean(pqc) - statistics.mean(classical)

    print("\nOverhead")
    print("-" * 40)
    print(f"Latency difference: {overhead:.2f} ms")


if __name__ == "__main__":
    main()