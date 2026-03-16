class HandshakeMetrics:
    def __init__(self, latency_ms, cipher_suite, key_exchange):
        self.latency_ms = latency_ms
        self.cipher_suite = cipher_suite
        self.key_exchange = key_exchange

class RequestMetrics:
    def __init__(self, latency_ms, provider_name):
        self.latency_ms = latency_ms
        self.provider_name = provider_name
