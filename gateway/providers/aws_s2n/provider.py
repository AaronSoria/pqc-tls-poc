from gateway.core.crypto_provider_interface import CryptoProvider

class AwsS2NProvider(CryptoProvider):

    def start_gateway(self, port: int):
        print("Starting AWS s2n TLS gateway on", port)

    def send_request(self, url: str):
        print("Sending request via s2n")

    def get_metrics(self):
        return {}