from client.classical_client import run as classical_run
from client.pqc_client import run as pqc_run
from client.aws_cross_stack_run import run as aws_cross_stack_run
from client.aws_same_stack_run import run as aws_same_stack_run


def print_result(name, result):
    if result is None:
        print(f"{name:<20} ERROR")
        return
    overhead_note = ""
    if "overhead_subtracted_ms" in result:
        overhead_note = f" (process overhead subtracted: {result['overhead_subtracted_ms']:.1f}ms)"
    print(
        f"{name:<20} "
        f"{result['mean']:.2f} ms (mean) | "
        f"{result['p50']:.2f} p50 | "
        f"{result['p95']:.2f} p95"
        f"{overhead_note}"
    )


def benchmark():
    print("\n🚀 Running TLS benchmark\n")

    classical = classical_run()
    pqc = pqc_run()
    #aws_cross = aws_cross_stack_run()
    aws_same = aws_same_stack_run()

    print("\nResults:\n")
    print("-" * 60)

    print_result("Classical TLS", classical)
    print_result("OQS PQC TLS", pqc)
    #print_result("AWS PQ TLS (cross-stack)", aws_cross)
    print_result("AWS PQ TLS (same-stack)", aws_same)

    print("-" * 60)


if __name__ == "__main__":
    benchmark()