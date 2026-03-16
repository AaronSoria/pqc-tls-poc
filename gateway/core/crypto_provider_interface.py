class CryptoProvider:
    def start_gateway(self, port: int):
        raise NotImplementedError()

    def send_request(self, url: str):
        raise NotImplementedError()

    def get_metrics(self):
        raise NotImplementedError()
