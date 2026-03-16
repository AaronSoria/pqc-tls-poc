class HandshakeMetrics:
    def __init__(self, latency_ms, cipher_suite, key_exchange):
        self.latency_ms = latency_ms
        self.cipher_suite = cipher_suite
        self.key_exchange = key_exchange