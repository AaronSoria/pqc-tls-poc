package oqs

import (
	"fmt"
	"os/exec"
	"strings"
	"time"

	"benchmark-go/internal/stats"
)

// subprocessOverheadSamples controls how many no-op subprocess calls are
// used to estimate the process-launch baseline.
const subprocessOverheadSamples = 10

// Run benchmarks OQS PQC TLS via subprocess openssl s_client.
//
// Because the hot path runs in a subprocess, we cannot instrument the TCP
// dial or TLS handshake directly. Instead we:
//   - Measure subprocess launch overhead using `openssl version` (no TLS).
//   - Report: Init = subprocess overhead, Handshake = total - overhead (estimate).
//   - Dial is folded into the subprocess and cannot be isolated.
//
// For true phase isolation, OQS would need CGO bindings to oqs-provider.
func Run(host string, port int, iterations int) (*stats.DetailedResult, error) {
	addr := fmt.Sprintf("%s:%d", host, port)

	// Measure subprocess launch overhead (openssl version — no TLS)
	subOverhead := measureSubprocessOverhead()

	// Warmup
	_ = doHandshake(addr)

	phases := make([]stats.PhaseTimings, 0, iterations)
	failures := 0

	for i := 0; i < iterations; i++ {
		t0 := time.Now()
		err := doHandshake(addr)
		total := time.Since(t0).Seconds() * 1000

		if err != nil {
			failures++
			fmt.Printf("OQS error: %v\n", err)
			continue
		}

		// Estimated handshake = total wall-clock minus subprocess launch overhead.
		// Dial (TCP loopback) is included in the subprocess and cannot be
		// isolated without modifying openssl s_client.
		estimated := total - subOverhead
		if estimated < 0 {
			estimated = 0
		}

		phases = append(phases, stats.PhaseTimings{
			Init:      subOverhead, // subprocess launch (fork+exec+dynamic linking)
			Dial:      0,           // folded into subprocess, not isolatable
			Handshake: estimated,   // estimated: total - subprocess overhead
			Total:     total,
		})
	}

	return stats.ComputeDetailed(phases, failures), nil
}

// measureSubprocessOverhead estimates the cost of launching an openssl
// subprocess by timing `openssl version` (no TLS involved).
func measureSubprocessOverhead() float64 {
	var total float64
	for i := 0; i < subprocessOverheadSamples; i++ {
		t0 := time.Now()
		cmd := exec.Command("openssl", "version")
		_ = cmd.Run()
		total += time.Since(t0).Seconds() * 1000
	}
	return total / float64(subprocessOverheadSamples)
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
		output := string(out)
		if strings.Contains(output, "SSL handshake has read") ||
			strings.Contains(output, "Cipher    :") {
			return nil
		}
		return fmt.Errorf("openssl failed: %w\noutput: %s", err, output)
	}
	return nil
}
