import subprocess
import time
import statistics


def run(host="aws-pq-server", port=10443, iterations=10):
    times = []

    for _ in range(iterations):
        start = time.perf_counter()

        try:
            subprocess.run(
                [
                    "s2nc",
                    "--insecure",
                    "--ciphers", "default_pq",
                    host,
                    str(port)
                ],
                input=b"GET /\n",
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                timeout=5
            )

            end = time.perf_counter()
            times.append((end - start) * 1000)

        except Exception as e:
            print("AWS PQ error:", e)

    if not times:
        return None

    return {
        "mean": statistics.mean(times),
        "p50": statistics.median(times),
        "p95": sorted(times)[int(len(times) * 0.95) - 1],
        "min": min(times),
        "max": max(times),
    }