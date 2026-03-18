FROM python:3.10-slim

WORKDIR /app

COPY . .

RUN apt-get update && apt-get install -y netcat-openbsd && rm -rf /var/lib/apt/lists/*
RUN pip install --no-cache-dir requests

ENV PYTHONPATH=/app

CMD ["python", "-m", "benchmark.run_benchmark"]