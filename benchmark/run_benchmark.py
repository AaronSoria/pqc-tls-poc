from client.classical_client import run as classical_run
from client.pqc_client import run as pqc_run
from client.aws_pq_client import run as aws_run


def print_result(name, result):
    if result is None:
        print(f"{name:<20} ERROR")
        return

    print(
        f"{name:<20} "
        f"{result['mean']:.2f} ms (mean) | "
        f"{result['p50']:.2f} p50 | "
        f"{result['p95']:.2f} p95"
    )


def benchmark():
    print("\n🚀 Running TLS benchmark\n")

    classical = classical_run()
    pqc = pqc_run()
    aws = aws_run()

    print("\nResults:\n")
    print("-" * 60)

    print_result("Classical TLS", classical)
    print_result("OQS PQC TLS", pqc)
    print_result("AWS PQ TLS", aws)

    print("-" * 60)


if __name__ == "__main__":
    benchmark()