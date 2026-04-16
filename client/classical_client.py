import ssl
import socket
import time
import statistics


def run(host="classical-server", port=8443, iterations=10):
    times = []

    context = ssl.create_default_context()
    context.check_hostname = False
    context.verify_mode = ssl.CERT_NONE

    for _ in range(iterations):
        start = time.perf_counter()

        try:
            with socket.create_connection((host, port), timeout=5) as sock:
                with context.wrap_socket(sock, server_hostname="localhost") as ssock:
                    ssock.send(b"GET / HTTP/1.1\r\nHost: localhost\r\n\r\n")
                    ssock.recv(1024)

            end = time.perf_counter()
            times.append((end - start) * 1000)

        except Exception as e:
            print("Classical error:", e)

    if not times:
        return None

    return {
        "mean": statistics.mean(times),
        "p50": statistics.median(times),
        "p95": sorted(times)[int(len(times) * 0.95) - 1],
        "min": min(times),
        "max": max(times),
    }