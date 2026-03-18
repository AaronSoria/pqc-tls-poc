import os

class Config:
    PQC_URL = os.getenv("PQC_URL", "https://localhost")
    CLASSICAL_URL = os.getenv("CLASSICAL_URL", "https://localhost")
    TIMEOUT = int(os.getenv("TIMEOUT", "5"))