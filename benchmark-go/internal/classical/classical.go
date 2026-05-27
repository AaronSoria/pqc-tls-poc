package classical

import (
	"crypto/tls"
	"fmt"
	"net"
	"time"

	"benchmark-go/internal/stats"
)

func Run(host string, port int, iterations int) (*stats.DetailedResult, error) {
	addr := fmt.Sprintf("%s:%d", host, port)
	cfg := &tls.Config{InsecureSkipVerify: true}

	// Warmup — prime TCP stack and TLS session cache
	if _, err := doHandshakePhased(addr, cfg); err != nil {
		return nil, fmt.Errorf("warmup failed: %w", err)
	}

	phases := make([]stats.PhaseTimings, 0, iterations)
	failures := 0

	for i := 0; i < iterations; i++ {
		pt, err := doHandshakePhased(addr, cfg)
		if err != nil {
			failures++
			fmt.Printf("Classical error: %v\n", err)
			continue
		}
		phases = append(phases, pt)
	}

	return stats.ComputeDetailed(phases, failures), nil
}

// doHandshakePhased times each phase of the TLS handshake separately:
//   Init      — tls.Client() wrapping (per-connection config overhead)
//   Dial      — TCP connect via net.DialTimeout
//   Handshake — crypto/tls TLS 1.3 negotiation
func doHandshakePhased(addr string, cfg *tls.Config) (stats.PhaseTimings, error) {
	var pt stats.PhaseTimings

	// Phase: TCP dial
	t0 := time.Now()
	conn, err := net.DialTimeout("tcp", addr, 5*time.Second)
	t1 := time.Now()
	if err != nil {
		return pt, err
	}
	defer conn.Close()
	pt.Dial = t1.Sub(t0).Seconds() * 1000

	// Phase: per-connection TLS client init (tls.Client wrapping + config copy)
	t2 := time.Now()
	tlsConn := tls.Client(conn, cfg)
	defer tlsConn.Close()
	t3 := time.Now()
	pt.Init = t3.Sub(t2).Seconds() * 1000

	// Phase: pure TLS handshake (ClientHello → Finished)
	t4 := time.Now()
	if err := tlsConn.Handshake(); err != nil {
		return pt, err
	}
	t5 := time.Now()
	pt.Handshake = t5.Sub(t4).Seconds() * 1000

	pt.Total = t5.Sub(t0).Seconds() * 1000
	return pt, nil
}
