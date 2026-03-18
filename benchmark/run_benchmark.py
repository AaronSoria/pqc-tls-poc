from client.classical_client import run as classical_run
from client.pqc_client import run as pqc_run


def benchmark():
    print("Running real TLS benchmark...\n")

    c = classical_run()
    p = pqc_run()

    print(f"{'Provider':<20} {'Latency (ms)':<15}")
    print("-" * 35)

    if c is not None:
        print(f"{'Classical TLS':<20} {c:<15.2f}")
    else:
        print(f"{'Classical TLS':<20} ERROR")

    if p is not None:
        print(f"{'PQC TLS':<20} {p:<15.2f}")
    else:
        print(f"{'PQC TLS':<20} ERROR")


if __name__ == "__main__":
    benchmark()