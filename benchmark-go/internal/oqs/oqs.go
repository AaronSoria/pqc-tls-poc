package oqs

import (
	"fmt"
	"os/exec"
	"strings"
	"time"

	"benchmark-go/internal/stats"
)

func Run(host string, port int, iterations int) (*stats.Result, error) {
	addr := fmt.Sprintf("%s:%d", host, port)

	// Warmup
	_ = doHandshake(addr)

	times := make([]float64, 0, iterations)
	failures := 0

	for i := 0; i < iterations; i++ {
		start := time.Now()
		err := doHandshake(addr)
		elapsed := time.Since(start).Seconds() * 1000 // ms

		if err != nil {
			failures++
			fmt.Printf("OQS error: %v\n", err)
			continue
		}
		times = append(times, elapsed)
	}

	return stats.Compute(times, failures), nil
}

func doHandshake(addr string) error {
	cmd := exec.Command(
		"openssl", "s_client",
		"-connect", addr,
		"-groups", "X25519MLKEM768",
		"-provider", "default",
		"-provider", "oqsprovider",
	)
	cmd.Stdin = strings.NewReader("Q\n")

	out, err := cmd.CombinedOutput()
	if err != nil {
		// openssl s_client exits non-zero on EOF — check if handshake succeeded
		output := string(out)
		if strings.Contains(output, "SSL handshake has read") ||
			strings.Contains(output, "Cipher    :") {
			return nil
		}
		return fmt.Errorf("openssl failed: %w\noutput: %s", err, output)
	}
	return nil
}
