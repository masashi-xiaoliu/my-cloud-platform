package main

import (
	"io"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"strings"
	"testing"
	"time"
)

func testApp(t *testing.T, mutate func(*Config)) *App {
	t.Helper()
	cfg := Config{
		Port:           "0",
		Message:        "Hello from My Cloud Platform",
		Env:            "test",
		LogLevel:       slog.LevelError,
		RequestTimeout: 2 * time.Second,
		MaxRetry:       1,
	}
	if mutate != nil {
		mutate(&cfg)
	}
	a := newApp(cfg, slog.New(slog.NewTextHandler(io.Discard, nil)))
	a.ready.Store(true)
	return a
}

func get(t *testing.T, h http.Handler, path string) (int, string) {
	t.Helper()
	rec := httptest.NewRecorder()
	h.ServeHTTP(rec, httptest.NewRequest(http.MethodGet, path, nil))
	return rec.Code, rec.Body.String()
}

// ★ LAB (CI-01): このテストの期待値を書き換えると CI が失敗する。docs/labs/cicd/README.md の C02 参照。
func TestRootReturnsMessage(t *testing.T) {
	code, body := get(t, testApp(t, nil).routes(), "/")
	if code != http.StatusOK {
		t.Fatalf("status = %d, want 200", code)
	}
	if !strings.Contains(body, "Hello from My Cloud Platform") {
		t.Fatalf("body = %q, want it to contain the message", body)
	}
}

func TestHealthAndReady(t *testing.T) {
	a := testApp(t, nil)
	h := a.routes()
	if code, _ := get(t, h, "/healthz"); code != 200 {
		t.Fatalf("/healthz = %d", code)
	}
	a.ready.Store(false)
	if code, _ := get(t, h, "/readyz"); code != 503 {
		t.Fatalf("/readyz while not ready = %d, want 503", code)
	}
}

func TestErrorRate100AlwaysFails(t *testing.T) {
	h := testApp(t, func(c *Config) { c.ErrorRate = 100 }).routes()
	if code, _ := get(t, h, "/"); code != 500 {
		t.Fatalf("status = %d, want 500", code)
	}
}

func TestRequestTimeout(t *testing.T) {
	h := testApp(t, func(c *Config) {
		c.LatencyMS = 200
		c.RequestTimeout = 50 * time.Millisecond
	}).routes()
	if code, _ := get(t, h, "/"); code != http.StatusServiceUnavailable {
		t.Fatalf("status = %d, want 503", code)
	}
}

func TestMetricsExposed(t *testing.T) {
	h := testApp(t, nil).routes()
	get(t, h, "/")
	_, body := get(t, h, "/metrics")
	for _, want := range []string{"http_requests_total{", "http_request_duration_seconds_bucket{", "app_info{"} {
		if !strings.Contains(body, want) {
			t.Errorf("metrics missing %q", want)
		}
	}
}

func TestUpstreamRetries(t *testing.T) {
	calls := 0
	up := httptest.NewServer(http.HandlerFunc(func(w http.ResponseWriter, _ *http.Request) {
		calls++
		w.WriteHeader(500)
	}))
	defer up.Close()
	h := testApp(t, func(c *Config) { c.UpstreamURL = up.URL; c.MaxRetry = 2 }).routes()
	if code, _ := get(t, h, "/upstream"); code != http.StatusBadGateway {
		t.Fatalf("status = %d, want 502", code)
	}
	if calls != 3 {
		t.Fatalf("upstream calls = %d, want 3 (1 + MAX_RETRY)", calls)
	}
}

func TestLoadConfigRequiresMessage(t *testing.T) {
	t.Setenv("APP_MESSAGE", "")
	if _, err := loadConfig(); err == nil {
		t.Fatal("expected error when APP_MESSAGE is empty")
	}
}

func TestLoadConfigRejectsBadValues(t *testing.T) {
	t.Setenv("APP_MESSAGE", "x")
	t.Setenv("ERROR_RATE", "150")
	if _, err := loadConfig(); err == nil {
		t.Fatal("expected error for ERROR_RATE=150")
	}
}
