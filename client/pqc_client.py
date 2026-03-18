import subprocess
import time


def run(host="oqs-server", port=9443, iterations=5):
    times = []

    for _ in range(iterations):
        start = time.time()

        try:
            subprocess.run(
                [
                    "openssl",
                    "s_client",
                    "-connect", f"{host}:{port}",
                    "-groups", "X25519MLKEM768",
                    "-provider", "default",
                    "-provider", "oqsprovider"
                ],
                input=b"Q",
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                timeout=5
            )

            end = time.time()
            times.append((end - start) * 1000)

        except Exception as e:
            print("PQC error:", e)

    if not times:
        return None

    return sum(times) / len(times)