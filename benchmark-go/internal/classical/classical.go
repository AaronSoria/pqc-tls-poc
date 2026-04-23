package classical

import (
	"crypto/tls"
	"fmt"
	"net"
	"time"

	"benchmark-go/internal/stats"
)

func Run(host string, port int, iterations int) (*stats.Result, error) {
	addr := fmt.Sprintf("%s:%d", host, port)

	cfg := &tls.Config{
		InsecureSkipVerify: true,
	}

	// Warmup
	if err := doHandshake(addr, cfg); err != nil {
		return nil, fmt.Errorf("warmup failed: %w", err)
	}

	times := make([]float64, 0, iterations)
	failures := 0

	for i := 0; i < iterations; i++ {
		start := time.Now()
		err := doHandshake(addr, cfg)
		elapsed := time.Since(start).Seconds() * 1000 // ms

		if err != nil {
			failures++
			fmt.Printf("Classical error: %v\n", err)
			continue
		}
		times = append(times, elapsed)
	}

	return stats.Compute(times, failures), nil
}

func doHandshake(addr string, cfg *tls.Config) error {
	conn, err := net.DialTimeout("tcp", addr, 5*time.Second)
	if err != nil {
		return err
	}
	defer conn.Close()

	tlsConn := tls.Client(conn, cfg)
	defer tlsConn.Close()

	if err := tlsConn.Handshake(); err != nil {
		return err
	}

	return nil
}
