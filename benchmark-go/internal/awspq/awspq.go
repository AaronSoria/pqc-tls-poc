package awspq

/*
#cgo CFLAGS: -I/opt/s2n-tls/api -I/opt/aws-lc/include
#cgo LDFLAGS: -L/opt/s2n-tls/build/lib -ls2n -L/opt/aws-lc/build/crypto -lcrypto -lpthread -ldl -lm

#include <s2n.h>
#include <stdlib.h>
#include <string.h>
#include <time.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <unistd.h>
#include <errno.h>

// Per-handshake phase timings in milliseconds.
typedef struct {
    double init_ms;      // s2n_config + s2n_connection setup
    double dial_ms;      // TCP connect (getaddrinfo + socket + connect)
    double handshake_ms; // s2n_negotiate (pure TLS negotiation)
    double total_ms;     // wall-clock total
} HandshakeTiming;

static double ts_diff_ms(struct timespec *a, struct timespec *b) {
    return (b->tv_sec - a->tv_sec) * 1000.0 + (b->tv_nsec - a->tv_nsec) / 1e6;
}

static int connect_tcp(const char *host, int port) {
    struct addrinfo hints, *res;
    char port_str[16];
    int fd;

    memset(&hints, 0, sizeof(hints));
    hints.ai_family   = AF_UNSPEC;
    hints.ai_socktype = SOCK_STREAM;
    snprintf(port_str, sizeof(port_str), "%d", port);

    if (getaddrinfo(host, port_str, &hints, &res) != 0) return -1;

    fd = socket(res->ai_family, res->ai_socktype, res->ai_protocol);
    if (fd < 0) { freeaddrinfo(res); return -1; }

    if (connect(fd, res->ai_addr, res->ai_addrlen) != 0) {
        close(fd);
        freeaddrinfo(res);
        return -1;
    }
    freeaddrinfo(res);
    return fd;
}

// do_s2n_handshake_timed performs a full TLS handshake and records
// per-phase timings using CLOCK_MONOTONIC.
// Returns 0 on success, -1 on error. timing is valid only on success.
static int do_s2n_handshake_timed(const char *host, int port,
                                   const char *cipher_pref,
                                   HandshakeTiming *timing) {
    struct timespec t0, t1, t2, t3;
    struct s2n_config     *config = NULL;
    struct s2n_connection *conn   = NULL;
    int fd = -1;
    int result = -1;
    s2n_blocked_status blocked;

    // --- Phase: init (s2n config + connection object setup) ---
    clock_gettime(CLOCK_MONOTONIC, &t0);

    config = s2n_config_new();
    if (!config) goto cleanup;
    if (s2n_config_set_cipher_preferences(config, cipher_pref) < 0) goto cleanup;
    if (s2n_config_disable_x509_verification(config) < 0) goto cleanup;

    conn = s2n_connection_new(S2N_CLIENT);
    if (!conn) goto cleanup;
    if (s2n_connection_set_config(conn, config) < 0) goto cleanup;
    if (s2n_set_server_name(conn, host) < 0) goto cleanup;

    clock_gettime(CLOCK_MONOTONIC, &t1);

    // --- Phase: dial (TCP connect) ---
    fd = connect_tcp(host, port);
    if (fd < 0) goto cleanup;
    if (s2n_connection_set_fd(conn, fd) < 0) goto cleanup;

    clock_gettime(CLOCK_MONOTONIC, &t2);

    // --- Phase: handshake (s2n_negotiate = pure TLS) ---
    if (s2n_negotiate(conn, &blocked) < 0) goto cleanup;

    clock_gettime(CLOCK_MONOTONIC, &t3);

    timing->init_ms      = ts_diff_ms(&t0, &t1);
    timing->dial_ms      = ts_diff_ms(&t1, &t2);
    timing->handshake_ms = ts_diff_ms(&t2, &t3);
    timing->total_ms     = ts_diff_ms(&t0, &t3);
    result = 0;

cleanup:
    if (conn) {
        s2n_connection_wipe(conn);
        s2n_connection_free(conn);
    }
    if (config) s2n_config_free(config);
    if (fd >= 0) close(fd);
    return result;
}

static int s2n_init_once() {
    return s2n_init();
}
*/
import "C"
import (
	"fmt"
	"sync"
	"unsafe"

	"benchmark-go/internal/stats"
)

var initOnce sync.Once
var initErr error

func initS2N() error {
	initOnce.Do(func() {
		ret := C.s2n_init_once()
		if ret < 0 {
			initErr = fmt.Errorf("s2n_init failed: %d", ret)
		}
	})
	return initErr
}

func Run(host string, port int, iterations int) (*stats.DetailedResult, error) {
	if err := initS2N(); err != nil {
		return nil, err
	}

	cHost := C.CString(host)
	cCipher := C.CString("default_pq")
	defer C.free(unsafe.Pointer(cHost))
	defer C.free(unsafe.Pointer(cCipher))

	// Warmup — AWS-LC initializes crypto tables on first call
	var warmupTiming C.HandshakeTiming
	C.do_s2n_handshake_timed(cHost, C.int(port), cCipher, &warmupTiming)

	phases := make([]stats.PhaseTimings, 0, iterations)
	failures := 0

	for i := 0; i < iterations; i++ {
		var ct C.HandshakeTiming
		ret := C.do_s2n_handshake_timed(cHost, C.int(port), cCipher, &ct)
		if ret < 0 {
			failures++
			fmt.Printf("AWS PQ error: s2n handshake failed\n")
			continue
		}
		phases = append(phases, stats.PhaseTimings{
			Init:      float64(ct.init_ms),
			Dial:      float64(ct.dial_ms),
			Handshake: float64(ct.handshake_ms),
			Total:     float64(ct.total_ms),
		})
	}

	return stats.ComputeDetailed(phases, failures), nil
}
