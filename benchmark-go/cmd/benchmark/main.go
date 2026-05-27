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

func printSummary(name string, result *stats.DetailedResult) {
	if result == nil {
		fmt.Printf("%-28s ERROR\n", name)
		return
	}
	fmt.Printf("%-28s %6.2f ms (mean) | %6.2f p50 | %6.2f p95 | %6.2f min | %6.2f max | ok=%d fail=%d\n",
		name,
		result.Mean, result.P50, result.P95, result.Min, result.Max,
		result.NSuccess, result.NFailure,
	)
}

func printPhaseRow(name string, r *stats.DetailedResult, initNote string) {
	if r == nil {
		fmt.Printf("%-28s  %-18s  %-18s  %-18s  %-18s\n",
			name, "ERROR", "ERROR", "ERROR", "ERROR")
		return
	}
	initStr := fmt.Sprintf("%.3f / %.3f", r.Init.P50, r.Init.P95)
	dialStr := fmt.Sprintf("%.3f / %.3f", r.Dial.P50, r.Dial.P95)
	hsStr := fmt.Sprintf("%.3f / %.3f", r.Handshake.P50, r.Handshake.P95)
	totStr := fmt.Sprintf("%.3f / %.3f", r.P50, r.P95)
	if initNote != "" {
		initStr += initNote
	}
	fmt.Printf("%-28s  %-18s  %-18s  %-18s  %-18s\n",
		name, initStr, dialStr, hsStr, totStr)
}

func main() {
	classicalHost := getEnv("CLASSICAL_HOST", "localhost")
	classicalPort := getEnvInt("CLASSICAL_PORT", 8443)

	pqcHost := getEnv("PQC_HOST", "localhost")
	pqcPort := getEnvInt("PQC_PORT", 9443)

	awsHost := getEnv("AWS_PQ_HOST", "localhost")
	awsPort := getEnvInt("AWS_PQ_PORT", 10443)

	iterations := getEnvInt("ITERATIONS", 50)

	fmt.Printf("\n🚀 PQC TLS Benchmark (Go) — %d iterations per stack\n\n", iterations)

	// ── Run all stacks ────────────────────────────────────────────────────────
	classicalResult, err := classical.Run(classicalHost, classicalPort, iterations)
	if err != nil {
		fmt.Printf("Classical setup error: %v\n", err)
	}

	oqsResult, err := oqs.Run(pqcHost, pqcPort, iterations)
	if err != nil {
		fmt.Printf("OQS setup error: %v\n", err)
	}

	awsResult, err := awspq.Run(awsHost, awsPort, iterations)
	if err != nil {
		fmt.Printf("AWS PQ setup error: %v\n", err)
	}

	// ── Table 1: summary (unchanged format) ──────────────────────────────────
	fmt.Printf("%-28s %s\n", "Stack", "Latency")
	fmt.Println("---------------------------------------------------------------------------------------------")
	printSummary("Classical TLS (RSA-2048)", classicalResult)
	printSummary("OQS PQC (X25519MLKEM768)", oqsResult)
	printSummary("AWS PQ (s2n + AWS-LC)", awsResult)
	fmt.Println("---------------------------------------------------------------------------------------------")

	// ── Table 2: phase breakdown P50 / P95 (ms) ──────────────────────────────
	fmt.Printf("\nPhase breakdown — P50 / P95 (ms)\n")
	fmt.Printf("%-28s  %-18s  %-18s  %-18s  %-18s\n",
		"Stack", "init", "dial (TCP)", "handshake (TLS)", "total")
	fmt.Println("──────────────────────────────────────────────────────────────────────────────────────────────")
	printPhaseRow("Classical TLS (RSA-2048)", classicalResult, "")
	printPhaseRow("OQS PQC (X25519MLKEM768)", oqsResult, " *est")
	printPhaseRow("AWS PQ (s2n + AWS-LC)", awsResult, "")
	fmt.Println("──────────────────────────────────────────────────────────────────────────────────────────────")
	fmt.Println()
	fmt.Println("Notes:")
	fmt.Println("  Classical : init = tls.Client() wrap; dial = net.Dial; handshake = crypto/tls TLS 1.3")
	fmt.Println("  AWS PQ    : init = s2n_config+conn setup; dial = TCP connect; handshake = s2n_negotiate")
	fmt.Println("  OQS PQC   : init = subprocess fork+exec overhead (openssl version baseline);")
	fmt.Println("              dial folded into subprocess (not isolatable without CGO bindings);")
	fmt.Println("              handshake* = total - subprocess overhead (estimate)")
}
