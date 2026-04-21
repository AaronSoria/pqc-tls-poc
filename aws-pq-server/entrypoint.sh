#!/bin/bash
set -e

openssl req -x509 -newkey rsa:2048 -nodes \
  -keyout /certs/aws-s2n-key.pem \
  -out /certs/aws-s2n-cert.pem \
  -days 1 \
  -subj '/CN=localhost'

echo 'Starting s2n PQ server...'
exec /opt/s2n-tls/build/bin/s2nd \
  --cert /certs/aws-s2n-cert.pem \
  --key /certs/aws-s2n-key.pem \
  --ciphers default_pq \
  --parallelize \
  --negotiate \
  --self-service-blinding \
  0.0.0.0 10443