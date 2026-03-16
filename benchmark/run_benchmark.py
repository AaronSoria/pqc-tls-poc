import time

def benchmark():
    start = time.time()
    # placeholder workload
    for _ in range(100):
        pass
    end = time.time()

    print("Benchmark duration:", end-start)

if __name__ == "__main__":
    benchmark()