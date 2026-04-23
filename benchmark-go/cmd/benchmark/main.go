package main

import (
	"fmt"
	"os"
	"strconv"

	"benchmark-go/internal/awspq"
	"benchmark-go/internal/classical"
	"benchmark-go/internal/oqs"
	"benchmark-go/internal/stats"
)

func getEnv(key, fallback string) string {
	if v := os.Getenv(key); v != "" {
		return v
	}
	return fallback
}

func getEnvInt(key string, fallback int) int {
	if v := os.Getenv(key); v != "" {
		if n, err := strconv.Atoi(v); err == nil {
			return n
		}
	}
	return fallback
}

func printResult(name string, result *stats.Result) {
	if result == nil {
		fmt.Printf("%-28s ERROR\n", name)
		return
	}
	fmt.Printf("%-28s %6.2f ms (mean) | %6.2f p50 | %6.2f p95 | %6.2f min | %6.2f max | ok=%d fail=%d\n",
		name,
		result.Mean,
		result.P50,
		result.P95,
		result.Min,
		result.Max,
		result.NSuccess,
		result.NFailure,
	)
}

func main() {
	classicalHost := getEnv("CLASSICAL_HOST", "classical-server")
	classicalPort := getEnvInt("CLASSICAL_PORT", 8443)

	pqcHost := getEnv("PQC_HOST", "oqs-server")
	pqcPort := getEnvInt("PQC_PORT", 9443)

	awsHost := getEnv("AWS_PQ_HOST", "aws-pq-server")
	awsPort := getEnvInt("AWS_PQ_PORT", 10443)

	iterations := getEnvInt("ITERATIONS", 20)

	fmt.Printf("\n🚀 PQC TLS Benchmark (Go) — %d iterations per stack\n\n", iterations)
	fmt.Printf("%-28s %s\n", "Stack", "Latency")
	fmt.Println("---------------------------------------------------------------------------------------------")

	// Classical TLS — crypto/tls nativo, sin subprocess
	classicalResult, err := classical.Run(classicalHost, classicalPort, iterations)
	if err != nil {
		fmt.Printf("Classical setup error: %v\n", err)
	}
	printResult("Classical TLS (RSA-2048)", classicalResult)

	// OQS PQC — subprocess openssl s_client con oqsprovider
	// (no hay bindings Go para oqs-provider, subprocess es inevitable)
	oqsResult, err := oqs.Run(pqcHost, pqcPort, iterations)
	if err != nil {
		fmt.Printf("OQS setup error: %v\n", err)
	}
	printResult("OQS PQC (X25519MLKEM768)", oqsResult)

	// AWS PQ — CGO contra libs2n + AWS-LC, handshake nativo en proceso
	awsResult, err := awspq.Run(awsHost, awsPort, iterations)
	if err != nil {
		fmt.Printf("AWS PQ setup error: %v\n", err)
	}
	printResult("AWS PQ (s2n + AWS-LC)", awsResult)

	fmt.Println("---------------------------------------------------------------------------------------------")
	fmt.Println()
	fmt.Println("Notas:")
	fmt.Println("  Classical : crypto/tls Go nativo — sin subprocess, medición directa del handshake")
	fmt.Println("  OQS       : subprocess openssl s_client — incluye overhead de proceso (~1-2ms)")
	fmt.Println("  AWS PQ    : CGO contra libs2n/AWS-LC — sin subprocess, medición directa del handshake")
}
