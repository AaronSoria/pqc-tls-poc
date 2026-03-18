import ssl
import socket
import time


def run(host="classical-server", port=8443, iterations=5):
    times = []

    context = ssl.create_default_context()
    context.check_hostname = False
    context.verify_mode = ssl.CERT_NONE

    for _ in range(iterations):
        start = time.time()

        try:
            with socket.create_connection((host, port)) as sock:
                with context.wrap_socket(sock, server_hostname="localhost") as ssock:
                    ssock.send(b"GET / HTTP/1.1\r\nHost: localhost\r\n\r\n")
                    ssock.recv(1024)

            end = time.time()
            times.append((end - start) * 1000)

        except Exception as e:
            print("Classical error:", e)

    if not times:
        return None

    return sum(times) / len(times)