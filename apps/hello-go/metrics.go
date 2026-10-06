package main

// 依存ライブラリなしで Prometheus テキスト形式を出力する最小実装。
// 学習用に「/metrics の中身は単なるテキスト」であることを見せる意図もある。
// 本番相当にするなら github.com/prometheus/client_golang に置き換える（docs/adr/0004 参照）。

import (
	"fmt"
	"net/http"
	"sort"
	"strings"
	"sync"
	"time"
)

var durationBuckets = []float64{0.005, 0.01, 0.025, 0.05, 0.1, 0.25, 0.5, 1, 2.5, 5, 10}

type histogram struct {
	counts []uint64 // 各 bucket（le）以下の件数（累積ではなく個別に保持し、出力時に累積する）
	sum    float64
	count  uint64
}

type Metrics struct {
	mu        sync.Mutex
	requests  map[string]uint64     // key: method|path|code
	durations map[string]*histogram // key: path
	version   string
	env       string
	start     time.Time
}

func newMetrics(version, env string) *Metrics {
	return &Metrics{
		requests:  map[string]uint64{},
		durations: map[string]*histogram{},
		version:   version,
		env:       env,
		start:     time.Now(),
	}
}

func (m *Metrics) observe(method, path string, code int, d time.Duration) {
	m.mu.Lock()
	defer m.mu.Unlock()
	m.requests[fmt.Sprintf("%s|%s|%d", method, path, code)]++
	h, ok := m.durations[path]
	if !ok {
		h = &histogram{counts: make([]uint64, len(durationBuckets))}
		m.durations[path] = h
	}
	s := d.Seconds()
	for i, b := range durationBuckets {
		if s <= b {
			h.counts[i]++
			break
		}
	}
	h.sum += s
	h.count++
}

func (m *Metrics) handler(w http.ResponseWriter, _ *http.Request) {
	m.mu.Lock()
	defer m.mu.Unlock()
	var b strings.Builder
	w.Header().Set("Content-Type", "text/plain; version=0.0.4")

	b.WriteString("# HELP app_info Application build information.\n# TYPE app_info gauge\n")
	fmt.Fprintf(&b, "app_info{version=%q,env=%q} 1\n", m.version, m.env)

	b.WriteString("# HELP app_uptime_seconds Seconds since the process started.\n# TYPE app_uptime_seconds gauge\n")
	fmt.Fprintf(&b, "app_uptime_seconds %f\n", time.Since(m.start).Seconds())

	b.WriteString("# HELP http_requests_total Total HTTP requests.\n# TYPE http_requests_total counter\n")
	keys := make([]string, 0, len(m.requests))
	for k := range m.requests {
		keys = append(keys, k)
	}
	sort.Strings(keys)
	for _, k := range keys {
		p := strings.SplitN(k, "|", 3)
		fmt.Fprintf(&b, "http_requests_total{method=%q,path=%q,code=%q} %d\n", p[0], p[1], p[2], m.requests[k])
	}

	b.WriteString("# HELP http_request_duration_seconds HTTP request latency.\n# TYPE http_request_duration_seconds histogram\n")
	paths := make([]string, 0, len(m.durations))
	for p := range m.durations {
		paths = append(paths, p)
	}
	sort.Strings(paths)
	for _, p := range paths {
		h := m.durations[p]
		var cum uint64
		for i, le := range durationBuckets {
			cum += h.counts[i]
			fmt.Fprintf(&b, "http_request_duration_seconds_bucket{path=%q,le=%q} %d\n", p, fmt.Sprint(le), cum)
		}
		fmt.Fprintf(&b, "http_request_duration_seconds_bucket{path=%q,le=\"+Inf\"} %d\n", p, h.count)
		fmt.Fprintf(&b, "http_request_duration_seconds_sum{path=%q} %f\n", p, h.sum)
		fmt.Fprintf(&b, "http_request_duration_seconds_count{path=%q} %d\n", p, h.count)
	}
	w.Write([]byte(b.String()))
}
