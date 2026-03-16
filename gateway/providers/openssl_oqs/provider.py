from gateway.core.crypto_provider_interface import CryptoProvider

class OpenSSLOQSProvider(CryptoProvider):

    def start_gateway(self, port: int):
        print("Starting OpenSSL OQS TLS gateway on", port)

    def send_request(self, url: str):
        print("Sending request via OpenSSL OQS")

    def get_metrics(self):
        return {}
