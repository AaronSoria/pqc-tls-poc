import os
import socket
import statistics
import subprocess
import time


def _calc_p95(times: list[float]) -> float:
    if not times:
        return 0.0
    ordered = sorted(times)
    index = max(0, min(len(ordered) - 1, int(len(ordered) * 0.95) - 1))
    return ordered[index]


def _measure_startup_overhead() -> float:
    """Measure s2nc process startup cost excluding actual TLS work."""
    times = []
    for _ in range(5):
        start = time.perf_counter()
        subprocess.run(["s2nc", "--help"], capture_output=True)
        times.append((time.perf_counter() - start) * 1000)
    return statistics.median(times)


def _measure_tcp_baseline(host: str, port: int) -> float:
    """Measure raw TCP connection time with no TLS."""
    times = []
    for _ in range(5):
        try:
            start = time.perf_counter()
            s = socket.create_connection((host, port), timeout=5)
            s.close()
            times.append((time.perf_counter() - start) * 1000)
        except Exception:
            pass
    return statistics.median(times) if times else 0.0


def run(host: str = "aws-pq-server", port: int = 10443, iterations: int = 10):
    host = os.getenv("AWS_PQ_HOST", host)
    port = int(os.getenv("AWS_PQ_PORT", port))
    iterations = int(os.getenv("ITERATIONS", iterations))

    cmd = ["s2nc", "--insecure", "--ciphers", "default_pq", host, str(port)]

    # Measure overhead components to subtract from raw timings
    startup_overhead = _measure_startup_overhead()
    tcp_baseline = _measure_tcp_baseline(host, port)
    process_overhead = startup_overhead + tcp_baseline

    # Warmup
    subprocess.run(cmd, input=b"\n", stdout=subprocess.DEVNULL,
                   stderr=subprocess.DEVNULL, timeout=5, check=False)

    times: list[float] = []
    failures = 0

    for _ in range(iterations):
        try:
            start = time.perf_counter()
            result = subprocess.run(
                cmd, input=b"\n",
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                timeout=5, check=False,
            )
            end = time.perf_counter()
            if result.returncode == 0:
                raw_ms = (end - start) * 1000
                adjusted_ms = max(0.1, raw_ms - process_overhead)
                times.append(adjusted_ms)
            else:
                failures += 1
        except Exception as e:
            failures += 1
            print("AWS PQ error:", e)

    if not times:
        return None

    return {
        "mean": statistics.mean(times),
        "p50": statistics.median(times),
        "p95": _calc_p95(times),
        "min": min(times),
        "max": max(times),
        "n_success": len(times),
        "n_failures": failures,
        "overhead_subtracted_ms": round(process_overhead, 2),
    }