from gateway.core.crypto_provider_interface import CryptoProvider
import time
from gateway.core.metrics import HandshakeMetrics

class OpenSSLOQSProvider(CryptoProvider):

    def start_gateway(self, port: int):
        print("Starting OpenSSL OQS TLS gateway on", port)

    def send_request(self, url: str):
        print("Sending request via OpenSSL OQS")

    def get_metrics(self):
        # Simulación de una negociación TLS
        start_time = time.time()
        # Placeholder para la simulación de la negociación TLS
        time.sleep(0.1)  # Simula un retraso de 100 ms
        end_time = time.time()

        latency_ms = (end_time - start_time) * 1000
        cipher_suite = "ECDHE-OQS"
        key_exchange = "OQS-KEM"

        return HandshakeMetrics(latency_ms, cipher_suite, key_exchange)
