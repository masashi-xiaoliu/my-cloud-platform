// hello-go: My Cloud Platform の「20% 側」サンプルアプリケーション。
//
// アプリ自体は極限まで単純にしてある。目的はアプリ開発ではなくインフラ学習。
// そのかわり「設定値を変えると挙動が変わる」ノブ（環境変数）を多数用意している。
// どのノブが、どの Tuning Lab / Incident Lab で使われるかは README の Tuning Lab 一覧を参照。
//
// Platform Contract（80% 側の基盤がアプリに求める約束）:
//   - PORT で待ち受ける
//   - GET /healthz  : プロセスが生きていれば 200（livenessProbe）
//   - GET /readyz   : リクエストを受けられる状態なら 200（readinessProbe）
//   - GET /metrics  : Prometheus 形式のメトリクス
//   - 標準出力に JSON 1 行 1 イベントでログを出す
//   - SIGTERM で graceful shutdown
package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"log/slog"
	"math/rand"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"sync/atomic"
	"syscall"
	"time"
)

// version はビルド時に -ldflags "-X main.version=v1.0.0" で埋め込まれる。
var version = "dev"

// Config はすべて環境変数から読み込む（12-Factor App）。
type Config struct {
	Port           string        // PORT
	Message        string        // APP_MESSAGE（必須。空だと起動失敗 → CrashLoopBackOff の教材）
	Env            string        // APP_ENV
	LogLevel       slog.Level    // LOG_LEVEL: debug|info|warn|error
	RequestTimeout time.Duration // REQUEST_TIMEOUT: 例 "5s"
	MaxRetry       int           // MAX_RETRY: /upstream の再試行回数
	UpstreamURL    string        // UPSTREAM_URL: /upstream が呼ぶ外部 API
	ErrorRate      int           // ERROR_RATE: "/" が 500 を返す確率（0-100）
	LatencyMS      int           // LATENCY_MS: "/" に人工的な遅延を入れる
	StartupDelay   time.Duration // STARTUP_DELAY_SECONDS: Ready になるまでの時間
	MemoryBallast  int           // MEMORY_BALLAST_MB: 起動時に確保するメモリ（OOMKilled の教材）
	APIKey         string        // API_KEY（Secret から注入）
	RequireAPIKey  bool          // REQUIRE_API_KEY: true なのに API_KEY が空なら起動失敗
}

func loadConfig() (Config, error) {
	c := Config{
		Port:          getenv("PORT", "8080"),
		Message:       os.Getenv("APP_MESSAGE"),
		Env:           getenv("APP_ENV", "local"),
		UpstreamURL:   os.Getenv("UPSTREAM_URL"),
		APIKey:        os.Getenv("API_KEY"),
		RequireAPIKey: os.Getenv("REQUIRE_API_KEY") == "true",
	}
	var errs []error

	switch getenv("LOG_LEVEL", "info") {
	case "debug":
		c.LogLevel = slog.LevelDebug
	case "info":
		c.LogLevel = slog.LevelInfo
	case "warn":
		c.LogLevel = slog.LevelWarn
	case "error":
		c.LogLevel = slog.LevelError
	default:
		errs = append(errs, fmt.Errorf("LOG_LEVEL must be one of debug|info|warn|error"))
	}

	d, err := time.ParseDuration(getenv("REQUEST_TIMEOUT", "5s"))
	if err != nil || d <= 0 {
		errs = append(errs, fmt.Errorf("REQUEST_TIMEOUT is invalid: %q", os.Getenv("REQUEST_TIMEOUT")))
	}
	c.RequestTimeout = d

	c.MaxRetry, err = atoiEnv("MAX_RETRY", 3, 0, 10)
	errs = appendErr(errs, err)
	c.ErrorRate, err = atoiEnv("ERROR_RATE", 0, 0, 100)
	errs = appendErr(errs, err)
	c.LatencyMS, err = atoiEnv("LATENCY_MS", 0, 0, 60000)
	errs = appendErr(errs, err)
	sd, err := atoiEnv("STARTUP_DELAY_SECONDS", 0, 0, 600)
	errs = appendErr(errs, err)
	c.StartupDelay = time.Duration(sd) * time.Second
	c.MemoryBallast, err = atoiEnv("MEMORY_BALLAST_MB", 0, 0, 8192)
	errs = appendErr(errs, err)

	if c.Message == "" {
		errs = append(errs, errors.New("APP_MESSAGE is required (check ConfigMap)"))
	}
	if c.RequireAPIKey && c.APIKey == "" {
		errs = append(errs, errors.New("API_KEY is required when REQUIRE_API_KEY=true (check Secret)"))
	}
	return c, errors.Join(errs...)
}

func main() {
	cfg, err := loadConfig()
	if err != nil {
		// 設定エラーは即終了させる。Kubernetes 上では CrashLoopBackOff になり、
		// `kubectl logs --previous` でこのメッセージを確認できる。
		slog.New(slog.NewJSONHandler(os.Stdout, nil)).Error("invalid configuration", "error", err.Error())
		os.Exit(1)
	}
	logger := slog.New(slog.NewJSONHandler(os.Stdout, &slog.HandlerOptions{Level: cfg.LogLevel})).
		With("app", "hello-go", "version", version, "env", cfg.Env)
	slog.SetDefault(logger)

	// Memory ballast: 指定 MB を確保して実際に触る（RSS に乗せる）。
	// memory limit より大きくすると OOMKilled になる。
	var ballast []byte
	if cfg.MemoryBallast > 0 {
		ballast = make([]byte, cfg.MemoryBallast*1024*1024)
		for i := 0; i < len(ballast); i += 4096 {
			ballast[i] = 1
		}
		logger.Info("memory ballast allocated", "mb", cfg.MemoryBallast)
	}

	app := newApp(cfg, logger)
	srv := &http.Server{
		Addr:              ":" + cfg.Port,
		Handler:           app.routes(),
		ReadHeaderTimeout: 5 * time.Second,
	}

	go func() {
		if cfg.StartupDelay > 0 {
			logger.Info("simulating slow startup", "seconds", cfg.StartupDelay.Seconds())
			time.Sleep(cfg.StartupDelay)
		}
		app.ready.Store(true)
		logger.Info("ready")
	}()

	go func() {
		logger.Info("listening", "port", cfg.Port, "message", cfg.Message)
		if err := srv.ListenAndServe(); err != nil && !errors.Is(err, http.ErrServerClosed) {
			logger.Error("server error", "error", err.Error())
			os.Exit(1)
		}
	}()

	// Graceful shutdown: Rolling Update / Pod 削除時に SIGTERM が送られる。
	stop := make(chan os.Signal, 1)
	signal.Notify(stop, syscall.SIGTERM, syscall.SIGINT)
	sig := <-stop
	logger.Info("shutdown signal received", "signal", sig.String())
	app.ready.Store(false) // まず readiness を落として新規トラフィックを止める
	ctx, cancel := context.WithTimeout(context.Background(), 10*time.Second)
	defer cancel()
	_ = srv.Shutdown(ctx)
	_ = ballast
	logger.Info("bye")
}

// ---------------------------------------------------------------------------

type App struct {
	cfg     Config
	log     *slog.Logger
	ready   atomic.Bool
	metrics *Metrics
	host    string
	client  *http.Client
}

func newApp(cfg Config, log *slog.Logger) *App {
	host, _ := os.Hostname() // Kubernetes では Pod 名になる
	return &App{
		cfg:     cfg,
		log:     log,
		metrics: newMetrics(version, cfg.Env),
		host:    host,
		client:  &http.Client{Timeout: 2 * time.Second},
	}
}

func (a *App) routes() http.Handler {
	mux := http.NewServeMux()
	mux.HandleFunc("GET /{$}", a.handleRoot)
	mux.HandleFunc("GET /info", a.handleInfo)
	mux.HandleFunc("GET /healthz", func(w http.ResponseWriter, _ *http.Request) { w.Write([]byte("ok")) })
	mux.HandleFunc("GET /readyz", a.handleReady)
	mux.HandleFunc("GET /metrics", a.metrics.handler)
	mux.HandleFunc("GET /burn", a.handleBurn)
	mux.HandleFunc("GET /error", func(w http.ResponseWriter, _ *http.Request) {
		http.Error(w, "intentional error", http.StatusInternalServerError)
	})
	mux.HandleFunc("GET /upstream", a.handleUpstream)

	// REQUEST_TIMEOUT を超えた処理は 503 を返す。
	timeout := http.TimeoutHandler(mux, a.cfg.RequestTimeout, "request timeout\n")
	return a.instrument(timeout)
}

// GET / : メッセージを返す。ERROR_RATE / LATENCY_MS の影響を受ける。
func (a *App) handleRoot(w http.ResponseWriter, r *http.Request) {
	if a.cfg.LatencyMS > 0 {
		select {
		case <-time.After(time.Duration(a.cfg.LatencyMS) * time.Millisecond):
		case <-r.Context().Done():
			return
		}
	}
	if a.cfg.ErrorRate > 0 && rand.Intn(100) < a.cfg.ErrorRate {
		a.log.Warn("injected error", "error_rate", a.cfg.ErrorRate)
		http.Error(w, "injected error", http.StatusInternalServerError)
		return
	}
	fmt.Fprintf(w, "%s (version=%s, pod=%s)\n", a.cfg.Message, version, a.host)
}

// GET /info : 現在の設定を返す（Secret の値そのものは返さない）。
func (a *App) handleInfo(w http.ResponseWriter, _ *http.Request) {
	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]any{
		"message":         a.cfg.Message,
		"version":         version,
		"env":             a.cfg.Env,
		"pod":             a.host,
		"log_level":       a.cfg.LogLevel.String(),
		"request_timeout": a.cfg.RequestTimeout.String(),
		"max_retry":       a.cfg.MaxRetry,
		"error_rate":      a.cfg.ErrorRate,
		"latency_ms":      a.cfg.LatencyMS,
		"api_key_set":     a.cfg.APIKey != "",
		"upstream_url":    a.cfg.UpstreamURL,
	})
}

func (a *App) handleReady(w http.ResponseWriter, _ *http.Request) {
	if !a.ready.Load() {
		http.Error(w, "not ready", http.StatusServiceUnavailable)
		return
	}
	w.Write([]byte("ready"))
}

// GET /burn?ms=200 : 指定ミリ秒 CPU を使い切る（HPA / CPU limit の教材）。
func (a *App) handleBurn(w http.ResponseWriter, r *http.Request) {
	ms, err := strconv.Atoi(r.URL.Query().Get("ms"))
	if err != nil || ms <= 0 {
		ms = 100
	}
	if ms > 5000 {
		ms = 5000
	}
	start := time.Now()
	deadline := start.Add(time.Duration(ms) * time.Millisecond)
	x := 0
	for time.Now().Before(deadline) {
		x++
	}
	a.log.Debug("burn", "ms", ms, "iterations", x)
	fmt.Fprintf(w, "burned cpu for %dms (wall=%s)\n", ms, time.Since(start).Round(time.Millisecond))
}

// GET /upstream : UPSTREAM_URL を MAX_RETRY 回まで再試行して呼ぶ（DNS / Network / 外部 API の教材）。
func (a *App) handleUpstream(w http.ResponseWriter, r *http.Request) {
	if a.cfg.UpstreamURL == "" {
		http.Error(w, "UPSTREAM_URL is not configured", http.StatusNotImplemented)
		return
	}
	var lastErr error
	for attempt := 0; attempt <= a.cfg.MaxRetry; attempt++ {
		req, _ := http.NewRequestWithContext(r.Context(), http.MethodGet, a.cfg.UpstreamURL, nil)
		if a.cfg.APIKey != "" {
			req.Header.Set("Authorization", "Bearer "+a.cfg.APIKey)
		}
		resp, err := a.client.Do(req)
		if err == nil && resp.StatusCode < 500 {
			resp.Body.Close()
			fmt.Fprintf(w, "upstream ok: status=%d attempts=%d\n", resp.StatusCode, attempt+1)
			return
		}
		if err == nil {
			resp.Body.Close()
			err = fmt.Errorf("upstream status %d", resp.StatusCode)
		}
		lastErr = err
		a.log.Warn("upstream call failed", "attempt", attempt+1, "max_retry", a.cfg.MaxRetry, "error", err.Error())
		time.Sleep(time.Duration(100*(attempt+1)) * time.Millisecond)
	}
	http.Error(w, "upstream failed: "+lastErr.Error(), http.StatusBadGateway)
}

// instrument: 全リクエストのメトリクスとアクセスログを記録する。
func (a *App) instrument(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()
		rec := &statusRecorder{ResponseWriter: w, status: http.StatusOK}
		next.ServeHTTP(rec, r)
		dur := time.Since(start)
		path := normalizePath(r.URL.Path)
		a.metrics.observe(r.Method, path, rec.status, dur)
		if path == "/metrics" || path == "/healthz" || path == "/readyz" {
			a.log.Debug("request", "method", r.Method, "path", r.URL.Path, "status", rec.status, "duration_ms", dur.Milliseconds())
			return
		}
		lvl := slog.LevelInfo
		if rec.status >= 500 {
			lvl = slog.LevelError
		}
		a.log.Log(r.Context(), lvl, "request", "method", r.Method, "path", r.URL.Path, "status", rec.status, "duration_ms", dur.Milliseconds())
	})
}

type statusRecorder struct {
	http.ResponseWriter
	status int
}

func (s *statusRecorder) WriteHeader(code int) {
	s.status = code
	s.ResponseWriter.WriteHeader(code)
}

// ラベルのカーディナリティ爆発を防ぐため、既知のパス以外は "other" にまとめる。
func normalizePath(p string) string {
	switch p {
	case "/", "/info", "/healthz", "/readyz", "/metrics", "/burn", "/error", "/upstream":
		return p
	}
	return "other"
}

func getenv(k, def string) string {
	if v, ok := os.LookupEnv(k); ok && v != "" {
		return v
	}
	return def
}

func atoiEnv(k string, def, min, max int) (int, error) {
	v := os.Getenv(k)
	if v == "" {
		return def, nil
	}
	n, err := strconv.Atoi(v)
	if err != nil || n < min || n > max {
		return def, fmt.Errorf("%s must be an integer between %d and %d (got %q)", k, min, max, v)
	}
	return n, nil
}

func appendErr(errs []error, err error) []error {
	if err != nil {
		return append(errs, err)
	}
	return errs
}
