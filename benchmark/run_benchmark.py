import time
from ..client.classical_client import run as classical_run
from ..client.pqc_client import run as pqc_run

def benchmark():
    start = time.time()
    # Ejecutar cliente clásico
    classical_start = time.time()
    classical_run()
    classical_end = time.time()
    classical_latency_ms = (classical_end - classical_start) * 1000

    # Ejecutar cliente PQC
    pqc_start = time.time()
    pqc_run()
    pqc_end = time.time()
    pqc_latency_ms = (pqc_end - pqc_start) * 1000

    end = time.time()

    print("Benchmark duration:", end - start)
    print("\nLatency Metrics:")
    print(f"{'Client':<20} {'Latency (ms)':<15}")
    print("-" * 38)
    print(f"Classical TLS:<20 {classical_latency_ms:<15.2f}")
    print(f"PQC TLS:<20 {pqc_latency_ms:<15.2f}")

if __name__ == "__main__":
    benchmark()
