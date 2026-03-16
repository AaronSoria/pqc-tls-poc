import time
from gateway.core.gateway import QuantumTLSGateway
from gateway.core.metrics import RequestMetrics
from gateway.providers.openssl_oqs.provider import OpenSSLOQSProvider

def run():
    # Crear instancia del gateway con el proveedor OpenSSL OQS
    provider = OpenSSLOQSProvider()
    gateway = QuantumTLSGateway(provider)

    # Medir la latencia de ida y vuelta
    start_time = time.time()
    gateway.send_request("https://localhost")
    end_time = time.time()

    latency_ms = (end_time - start_time) * 1000

    # Devolver las métricas del benchmark
    return RequestMetrics(latency_ms, "OpenSSL OQS")

if __name__ == "__main__":
    metrics = run()
    print(f"Latency Metrics:")
    print(f"{'Provider':<20} {'Latency (ms)':<15}")
    print("-" * 38)
    print(f"{metrics.provider_name:<20} {metrics.latency_ms:<15.2f}")
