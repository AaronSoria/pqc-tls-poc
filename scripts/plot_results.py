import matplotlib.pyplot as plt
import pandas as pd
import numpy as np

# =========================
# LOAD GPU DATA
# =========================
gpu_df = pd.read_csv("../results/gpu_results_25_03_2026.csv", header=None)
gpu_df.columns = ["tag", "batch", "op", "latency_us"]

# limpiar datos
gpu_df = gpu_df[gpu_df["tag"] == "CSV"]

gpu_df["batch"] = pd.to_numeric(gpu_df["batch"])
gpu_df["latency_us"] = pd.to_numeric(gpu_df["latency_us"])

# average per batch/op

gpu_df = gpu_df.dropna()
gpu_avg = gpu_df.groupby(["batch", "op"])["latency_us"].mean().reset_index()

# =========================
# CPU DATA (manual parse)
# =========================

cpu_data = {
    "keygen": 9.54,
    "encaps": 9.73,
    "decaps": 12.25
}

# =========================
# TLS DATA (manual)
# =========================

tls_classical = 2.5 * 1000  # us
tls_pqc = 95 * 1000         # us

# =========================
# 1. GPU SCALING
# =========================

plt.figure()
for op in ["keygen", "encaps", "decaps"]:
    subset = gpu_avg[gpu_avg["op"] == op]
    plt.plot(subset["batch"], subset["latency_us"], marker="o", label=op)

plt.xscale("log")
plt.xlabel("Batch size (log scale)")
plt.ylabel("Latency (μs/op)")
plt.title("GPU ML-KEM Scaling (cuPQC)")
plt.legend()
plt.grid(True)
plt.savefig("../results/gpu_scaling.png")

# =========================
# 2. CPU vs GPU
# =========================

ops = ["keygen", "encaps", "decaps"]

cpu_vals = [cpu_data[o] for o in ops]
gpu_single = [100, 99, 101]  # approx
gpu_batch = [0.82, 0.96, 1.02]

x = np.arange(len(ops))

plt.figure()
plt.bar(x - 0.2, cpu_vals, width=0.2, label="CPU")
plt.bar(x, gpu_single, width=0.2, label="GPU (batch=1)")
plt.bar(x + 0.2, gpu_batch, width=0.2, label="GPU (batch=8192)")

plt.xticks(x, ops)
plt.ylabel("Latency (μs)")
plt.title("CPU vs GPU ML-KEM Performance")
plt.legend()
plt.grid(True)
plt.savefig("../results/cpu_vs_gpu.png")

# =========================
# 3. TLS vs PQC
# =========================

labels = ["ML-KEM (CPU)", "TLS Classical", "TLS PQC"]
values = [10, tls_classical, tls_pqc]

plt.figure()
plt.bar(labels, values)
plt.yscale("log")
plt.ylabel("Latency (μs, log scale)")
plt.title("TLS vs PQC Cost Comparison")
plt.grid(True)
plt.savefig("../results/tls_vs_pqc.png")

print("Plots generated in ../results/")