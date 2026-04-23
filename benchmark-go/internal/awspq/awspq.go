package awspq

/*
#cgo CFLAGS: -I/opt/s2n-tls/api -I/opt/aws-lc/include
#cgo LDFLAGS: -L/opt/s2n-tls/build/lib -ls2n -L/opt/aws-lc/build/crypto -lcrypto -lpthread -ldl -lm

#include <s2n.h>
#include <stdlib.h>
#include <string.h>
#include <sys/socket.h>
#include <netinet/in.h>
#include <arpa/inet.h>
#include <netdb.h>
#include <unistd.h>
#include <errno.h>

static int connect_tcp(const char *host, int port) {
    struct addrinfo hints, *res;
    char port_str[16];
    int fd;

    memset(&hints, 0, sizeof(hints));
    hints.ai_family = AF_UNSPEC;
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

static int do_s2n_handshake(const char *host, int port, const char *cipher_pref) {
    struct s2n_config *config = NULL;
    struct s2n_connection *conn = NULL;
    int fd = -1;
    int result = -1;
    s2n_blocked_status blocked;

    config = s2n_config_new();
    if (!config) goto cleanup;

    if (s2n_config_set_cipher_preferences(config, cipher_pref) < 0) goto cleanup;
    if (s2n_config_disable_x509_verification(config) < 0) goto cleanup;

    conn = s2n_connection_new(S2N_CLIENT);
    if (!conn) goto cleanup;

    if (s2n_connection_set_config(conn, config) < 0) goto cleanup;
    if (s2n_set_server_name(conn, host) < 0) goto cleanup;

    fd = connect_tcp(host, port);
    if (fd < 0) goto cleanup;

    if (s2n_connection_set_fd(conn, fd) < 0) goto cleanup;

    if (s2n_negotiate(conn, &blocked) < 0) goto cleanup;

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
	"time"
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

func Run(host string, port int, iterations int) (*stats.Result, error) {
	if err := initS2N(); err != nil {
		return nil, err
	}

	cHost := C.CString(host)
	cCipher := C.CString("default_pq")
	defer C.free(unsafe.Pointer(cHost))
	defer C.free(unsafe.Pointer(cCipher))

	// Warmup — AWS-LC initializes crypto tables on first call
	C.do_s2n_handshake(cHost, C.int(port), cCipher)

	times := make([]float64, 0, iterations)
	failures := 0

	for i := 0; i < iterations; i++ {
		start := time.Now()
		ret := C.do_s2n_handshake(cHost, C.int(port), cCipher)
		elapsed := time.Since(start).Seconds() * 1000 // ms

		if ret < 0 {
			failures++
			fmt.Printf("AWS PQ error: s2n handshake failed\n")
			continue
		}
		times = append(times, elapsed)
	}

	return stats.Compute(times, failures), nil
}
