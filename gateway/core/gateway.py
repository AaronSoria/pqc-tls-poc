from .crypto_provider_interface import CryptoProvider

class QuantumTLSGateway:

    def __init__(self, provider: CryptoProvider):
        self.provider = provider

    def start(self, port=443):
        self.provider.start_gateway(port)
