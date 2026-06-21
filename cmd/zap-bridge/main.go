// Copyright (c) 2026 Hanzo Industries Inc.
// SPDX-License-Identifier: Apache-2.0
//
// zap-bridge — native ZAP duplex listener baked into the Hanzo Datastore
// image. Replaces the deleted out-of-process zap-sidecar bridge.
//
// One container, two processes:
//
//	hanzo-datastore server (PID 1, listens on 8123/HTTP + 9000/native)
//	zap-bridge             (background, listens on 9999/ZAP)
//
// On the wire, zap-bridge speaks the canonical Hanzo ZAP backend protocol:
//
//	MsgType:        302  (= MsgTypeDatastore — see hanzo/orm/db/zap.go,
//	                      hanzo/cloud/object/zap.go; the deleted
//	                      hanzo/zap/internal/datastore/proxy.go used the
//	                      same value. Append-only — never rebind.)
//
//	Request fields:
//	  fieldPath = 4   Text   request path (sub-method dispatch)
//	  fieldBody = 12  Bytes  JSON body
//	  fieldTS   = 20  Uint64 Unix-ms timestamp (replay guard)
//	  fieldHMAC = 28  Bytes  HMAC-SHA256(key, path || \x00 || body || \x00 || ts-bytes)
//
//	Response fields:
//	  respStatus  = 0   Uint32  HTTP-style status code
//	  respBody    = 4   Bytes   JSON or NDJSON response
//
// Sub-methods (path):
//
//	/health  liveness probe — returns 200 iff ClickHouse responds to SELECT 1.
//	/query   {sql, args?, database?} — runs SELECT, returns NDJSON.
//	/exec    {sql, args?, database?} — runs a non-SELECT, returns {ok:true}.
//	/insert  {table, database?, rows:[{...}]} — bulk insert via JSONEachRow.
//
// Authentication: every frame must carry a valid HMAC-SHA256 signature
// over (path || \x00 || body || \x00 || ts-bytes), keyed with the shared
// secret in DATASTORE_BRIDGE_HMAC_KEY (base64-encoded). Unsigned or
// invalid frames are rejected with 401. Replay protection: timestamps
// older than 60s or further than 60s in the future are rejected.
//
// Why MsgType 302 + path-based sub-dispatch (instead of a separate opcode
// per method, like hanzo/tasks/service/frontend/zap_handler.go does at
// 0x0060-0x009F): the orm client (hanzo/orm/db/zap.go) is already wired
// to send a single MsgType per backend with sub-dispatch via fieldPath.
// Changing that contract would break every downstream caller. Stick to the
// canonical pattern for sql/kv/datastore/docdb backends.
package main

import (
	"bytes"
	"context"
	"crypto/hmac"
	"crypto/sha256"
	"crypto/subtle"
	"encoding/base64"
	"encoding/binary"
	"encoding/json"
	"errors"
	"flag"
	"fmt"
	"log/slog"
	"net/http"
	"os"
	"os/signal"
	"strconv"
	"strings"
	"sync"
	"sync/atomic"
	"syscall"
	"time"

	"github.com/ClickHouse/clickhouse-go/v2"
	"github.com/ClickHouse/clickhouse-go/v2/lib/driver"
	"github.com/luxfi/zap"
)

// MsgTypeDatastore is the source-level canonical ID for the datastore
// backend, as used by hanzo/orm/db/zap.go and hanzo/cloud/object/zap.go.
//
// Wire dispatch quirk: luxfi/zap routes on `msg.Flags() >> 8`, which
// truncates the 16-bit msgType to its low byte. Senders write
// `FinishWithFlags(msgType << 8)` and the receiver compares against the
// 8-bit projection. So the *effective* on-wire dispatch key is
// `MsgTypeDatastore & 0xFF` = 0x2E (46). We register the handler on the
// 8-bit key and keep the 16-bit constant for source-level symmetry with
// the rest of the ecosystem. Append-only: do not rebind 302.
const MsgTypeDatastore uint16 = 302

// msgTypeDatastoreWire is the 8-bit dispatch key actually used on the
// wire. Computed once at compile time so the registration and the test
// builders stay in lockstep.
const msgTypeDatastoreWire uint16 = MsgTypeDatastore & 0xFF

// ZAP wire offsets — must match hanzo/orm/db/zap.go and
// hanzo/cloud/object/zap.go. Append-only.
//
// Request fields:
//   fieldPath = 4   Text   sub-method dispatch ("/health", "/query", ...)
//   fieldBody = 12  Bytes  JSON body
//   fieldTS   = 20  Uint64 Unix-ms timestamp for replay protection
//   fieldHMAC = 28  Bytes  HMAC-SHA256(key, path||0x00||body||0x00||ts-LE-bytes)
//
// Response fields:
//   respStatus = 0  Uint32  HTTP-style status code
//   respBody   = 4  Bytes   JSON or NDJSON payload
//
// Layout note: each Bytes field consumes 8 bytes inline (offset+length
// pointer). Bytes@4 occupies 4..11; Bytes@12 occupies 12..19; Uint64@20
// occupies 20..27; Bytes@28 occupies 28..35. Object fixed-section size
// is 36. The deleted respHeaders field at offset 8 was broken (its
// 8-byte slot collided with respBody at 4..11), so we dropped it.
const (
	fieldPath = 4
	fieldBody = 12
	fieldTS   = 20
	fieldHMAC = 28

	respStatus = 0
	respBody   = 4

	// objectFixedSize is the size to pass to StartObject for outgoing
	// requests. Matches the highest field-end offset (28+8=36).
	objectFixedSize = 36

	// hmacReplayWindow is how far in the past or future a request
	// timestamp may be before we reject it as replayed/forged. Tuned
	// for in-cluster RTT plus modest clock skew.
	hmacReplayWindow = 60 * time.Second

	// handlerTimeout caps every request's ClickHouse work. Bridge ctx
	// is bound to the node lifetime (no caller deadline propagation
	// from luxfi/zap); without this, slow CH queries pin connections
	// indefinitely after the caller has given up.
	handlerTimeout = 30 * time.Second

	// maxInsertRows is the per-request row cap. ZAP frames are already
	// capped at 10MiB upstream; this caps memory pressure across
	// concurrent inserts on top of that. 10k rows × ~1KiB/row ≈ 10MiB
	// matches the wire ceiling.
	maxInsertRows = 10_000

	// chMaxOpenConns is the ClickHouse connection-pool size. Two are
	// reserved for /health (semaphore admit gate is set to N-2).
	chMaxOpenConns = 10
)

// config gathers all runtime knobs. All have safe defaults — zero-flag
// invocation is the production path.
type config struct {
	listen      string // ZAP listen, default :9999
	clickhouse  string // ClickHouse native TCP, default 127.0.0.1:9000
	user        string // CH username, default "insights_writer"
	password    string // CH password, default ""
	database    string // default DB, default "insights"
	nodeID      string // ZAP NodeID, default hostname or "datastore"
	serviceType string // ZAP service, default "_hanzo._tcp"
	hmacKey     []byte // HMAC-SHA256 key, base64-decoded from env
}

func loadConfig() (config, error) {
	cfg := config{
		listen:      env("ZAP_LISTEN", ":9999"),
		clickhouse:  env("DATASTORE_NATIVE_ADDR", "127.0.0.1:9000"),
		user:        env("DATASTORE_USER", "insights_writer"),
		password:    env("DATASTORE_PASSWORD", ""),
		database:    env("DATASTORE_DB", "insights"),
		nodeID:      env("ZAP_NODE_ID", ""),
		serviceType: env("ZAP_SERVICE_TYPE", "_hanzo._tcp"),
	}
	flag.StringVar(&cfg.listen, "listen", cfg.listen, "ZAP listen address (host:port)")
	flag.StringVar(&cfg.clickhouse, "clickhouse", cfg.clickhouse, "ClickHouse native TCP address")
	flag.StringVar(&cfg.user, "user", cfg.user, "ClickHouse username")
	flag.StringVar(&cfg.password, "password", cfg.password, "ClickHouse password")
	flag.StringVar(&cfg.database, "database", cfg.database, "ClickHouse default database")
	flag.StringVar(&cfg.nodeID, "node-id", cfg.nodeID, "ZAP NodeID (default: $HOSTNAME or 'datastore')")
	flag.StringVar(&cfg.serviceType, "service-type", cfg.serviceType, "ZAP service type")
	flag.Parse()

	if cfg.nodeID == "" {
		if h, err := os.Hostname(); err == nil && h != "" {
			cfg.nodeID = h
		} else {
			cfg.nodeID = "datastore"
		}
	}

	keyB64 := os.Getenv("DATASTORE_BRIDGE_HMAC_KEY")
	if keyB64 == "" {
		return cfg, errors.New("DATASTORE_BRIDGE_HMAC_KEY required (base64-encoded ≥32 bytes)")
	}
	key, err := base64.StdEncoding.DecodeString(keyB64)
	if err != nil {
		return cfg, fmt.Errorf("DATASTORE_BRIDGE_HMAC_KEY: %w", err)
	}
	if len(key) < 32 {
		return cfg, fmt.Errorf("DATASTORE_BRIDGE_HMAC_KEY: %d bytes, need ≥32", len(key))
	}
	cfg.hmacKey = key
	return cfg, nil
}

func env(k, def string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return def
}

func main() {
	cfg, err := loadConfig()
	logger := slog.New(slog.NewJSONHandler(os.Stderr, &slog.HandlerOptions{Level: slog.LevelInfo})).
		With("component", "zap-bridge")
	if err != nil {
		logger.Error("config load failed", "err", err)
		os.Exit(1)
	}

	rootCtx, rootCancel := context.WithCancel(context.Background())
	defer rootCancel()

	br, err := newBridge(rootCtx, logger, cfg)
	if err != nil {
		logger.Error("bridge startup failed", "err", err)
		os.Exit(1)
	}
	defer br.close()

	logger.Info("zap-bridge ready",
		"listen", cfg.listen,
		"clickhouse", cfg.clickhouse,
		"db", cfg.database,
		"user", cfg.user,
	)

	// Graceful shutdown on SIGTERM/SIGINT. We drain in-flight ZAP requests
	// (5s grace), then stop the node, then return — main exits cleanly so
	// the supervisor (entrypoint.sh) doesn't restart the process.
	sigs := make(chan os.Signal, 1)
	signal.Notify(sigs, syscall.SIGTERM, syscall.SIGINT)
	sig := <-sigs
	logger.Info("signal received, draining", "signal", sig.String())

	rootCancel()
	br.shutdown(5 * time.Second)
}

// executor is the narrow surface of clickhouse-go/v2/lib/driver.Conn that
// the bridge actually uses. Defined here so unit tests can substitute a
// fake without standing up a live ClickHouse instance. We intentionally
// do NOT widen this — the philosophy is that abstractions exist only
// where there are at least two concrete implementations (driver.Conn in
// production, fakeExec in tests).
type executor interface {
	Query(ctx context.Context, query string, args ...any) (driver.Rows, error)
	QueryRow(ctx context.Context, query string, args ...any) driver.Row
	Exec(ctx context.Context, query string, args ...any) error
	PrepareBatch(ctx context.Context, query string, opts ...driver.PrepareBatchOption) (driver.Batch, error)
}

// bridge is the running zap-bridge process — owns the ZAP node and the
// ClickHouse connection pool.
type bridge struct {
	logger *slog.Logger
	cfg    config

	node *zap.Node
	ch   executor
	conn driver.Conn // nil in tests; canonical close target in production.

	// admit is the accept-side concurrency semaphore. It bounds the
	// number of concurrent CH-touching handlers below the pool size,
	// reserving headroom for /health and shutdown. Set to
	// chMaxOpenConns-2 = 8 in production.
	admit chan struct{}

	// inflight tracks in-progress handler invocations so shutdown can
	// drain rather than truncate. Atomic counter — handlers Add(1) on
	// entry and Add(-1) on exit; shutdown spins on this.
	inflight atomic.Int64

	closeOnce sync.Once
}

// newBridge connects to ClickHouse with retry, registers the ZAP handler,
// and starts the ZAP listener. Returns once the listener is bound.
func newBridge(ctx context.Context, logger *slog.Logger, cfg config) (*bridge, error) {
	conn, err := openClickHouse(ctx, logger, cfg)
	if err != nil {
		return nil, fmt.Errorf("clickhouse: %w", err)
	}

	port, err := portFromListen(cfg.listen)
	if err != nil {
		conn.Close()
		return nil, fmt.Errorf("listen %q: %w", cfg.listen, err)
	}

	node := zap.NewNode(zap.NodeConfig{
		NodeID:      cfg.nodeID,
		ServiceType: cfg.serviceType,
		Port:        port,
		NoDiscovery: true, // K8s — no mDNS multicast.
		Logger:      logger.With("subsys", "zap"),
	})

	br := &bridge{
		logger: logger,
		cfg:    cfg,
		node:   node,
		ch:     conn,
		conn:   conn,
		admit:  make(chan struct{}, chMaxOpenConns-2),
	}

	node.Handle(msgTypeDatastoreWire, func(hctx context.Context, from string, msg *zap.Message) (*zap.Message, error) {
		br.inflight.Add(1)
		defer br.inflight.Add(-1)
		return br.handle(hctx, from, msg), nil
	})

	if err := node.Start(); err != nil {
		conn.Close()
		return nil, fmt.Errorf("zap node start: %w", err)
	}

	return br, nil
}

// shutdown waits for in-flight handlers to drain (up to grace), then stops
// the ZAP node and closes ClickHouse. Idempotent.
func (b *bridge) shutdown(grace time.Duration) {
	deadline := time.Now().Add(grace)
	for b.inflight.Load() > 0 && time.Now().Before(deadline) {
		time.Sleep(10 * time.Millisecond)
	}
	if remaining := b.inflight.Load(); remaining > 0 {
		b.logger.Warn("shutdown grace expired with inflight requests", "inflight", remaining)
	}
	b.close()
}

func (b *bridge) close() {
	b.closeOnce.Do(func() {
		if b.node != nil {
			b.node.Stop()
		}
		if b.conn != nil {
			_ = b.conn.Close()
		}
	})
}

// openClickHouse opens a clickhouse-go connection with native-TCP transport
// and retries until the server is reachable. Retries are bounded — Docker
// orchestration ordering may bring the bridge up before the server is
// listening, so we wait up to 60s on cold starts.
func openClickHouse(ctx context.Context, logger *slog.Logger, cfg config) (driver.Conn, error) {
	opts := &clickhouse.Options{
		Addr: []string{cfg.clickhouse},
		Auth: clickhouse.Auth{
			Database: cfg.database,
			Username: cfg.user,
			Password: cfg.password,
		},
		DialTimeout:      10 * time.Second,
		MaxOpenConns:     chMaxOpenConns,
		MaxIdleConns:     5,
		ConnMaxLifetime:  time.Hour,
		ConnOpenStrategy: clickhouse.ConnOpenInOrder,
	}

	const maxAttempts = 30
	var lastErr error
	for attempt := 1; attempt <= maxAttempts; attempt++ {
		if ctx.Err() != nil {
			return nil, ctx.Err()
		}
		conn, err := clickhouse.Open(opts)
		if err == nil {
			pingCtx, cancel := context.WithTimeout(ctx, 5*time.Second)
			err = conn.Ping(pingCtx)
			cancel()
			if err == nil {
				return conn, nil
			}
			_ = conn.Close()
		}
		lastErr = err
		logger.Warn("clickhouse not ready", "attempt", attempt, "err", err)
		select {
		case <-ctx.Done():
			return nil, ctx.Err()
		case <-time.After(2 * time.Second):
		}
	}
	return nil, fmt.Errorf("clickhouse unreachable after %d attempts: %w", maxAttempts, lastErr)
}

// handle dispatches a ZAP message to the right sub-method based on the
// path field. Errors are encoded into the response — never returned to
// the ZAP layer (which would close the connection).
//
// Auth flow: HMAC validation runs first, before any handler logic. An
// invalid HMAC returns 401 with no information about why (timestamp out
// of range vs MAC mismatch are indistinguishable to attackers).
//
// Concurrency: every handler that touches CH passes through admit. The
// semaphore is small (8) — DoS via slow queries cannot starve /health.
// /health bypasses the gate so probes work even under saturation.
func (b *bridge) handle(ctx context.Context, _ string, msg *zap.Message) *zap.Message {
	root := msg.Root()
	if root.IsNull() {
		return respondJSON(http.StatusBadRequest, map[string]string{"error": "empty request"})
	}
	path := root.Text(fieldPath)
	body := root.Bytes(fieldBody)
	ts := root.Uint64(fieldTS)
	mac := root.Bytes(fieldHMAC)

	if !b.verifyHMAC(path, body, ts, mac) {
		return respondJSON(http.StatusUnauthorized, map[string]string{"error": "unauthorized"})
	}

	// Per-request deadline. The luxfi/zap node ctx is bound to node
	// lifetime; without an explicit deadline a slow CH query pins the
	// connection long after the caller has timed out. 30s matches the
	// orm client's default QueryTimeout.
	ctx, cancel := context.WithTimeout(ctx, handlerTimeout)
	defer cancel()

	switch path {
	case "/health":
		// /health bypasses the admit gate so probes work under saturation.
		return b.health(ctx)
	case "/query":
		if !b.acquire(ctx) {
			return respondJSON(http.StatusServiceUnavailable, map[string]string{"error": "busy"})
		}
		defer b.release()
		return b.query(ctx, body)
	case "/exec":
		if !b.acquire(ctx) {
			return respondJSON(http.StatusServiceUnavailable, map[string]string{"error": "busy"})
		}
		defer b.release()
		return b.exec(ctx, body)
	case "/insert":
		if !b.acquire(ctx) {
			return respondJSON(http.StatusServiceUnavailable, map[string]string{"error": "busy"})
		}
		defer b.release()
		return b.insert(ctx, body)
	default:
		return respondJSON(http.StatusNotFound, map[string]string{"error": "unknown path: " + path})
	}
}

// verifyHMAC checks the timestamp window and the MAC. Returns true iff
// the request is authentic AND fresh. Constant-time comparison.
//
// MAC payload: path || 0x00 || body || 0x00 || ts-LE-8-bytes. The 0x00
// separators prevent extension/cutting attacks across path/body boundaries.
func (b *bridge) verifyHMAC(path string, body []byte, ts uint64, mac []byte) bool {
	if len(mac) != sha256.Size {
		return false
	}
	if len(b.cfg.hmacKey) == 0 {
		return false
	}
	now := time.Now().UnixMilli()
	skew := int64(ts) - now
	if skew < -hmacReplayWindow.Milliseconds() || skew > hmacReplayWindow.Milliseconds() {
		return false
	}
	expected := computeHMAC(b.cfg.hmacKey, path, body, ts)
	return subtle.ConstantTimeCompare(expected, mac) == 1
}

// computeHMAC is the canonical HMAC payload format. Exposed so client
// libraries (orm/db/zap.go, cloud/object/zap.go) can compute matching
// signatures with the same code path.
func computeHMAC(key []byte, path string, body []byte, ts uint64) []byte {
	h := hmac.New(sha256.New, key)
	h.Write([]byte(path))
	h.Write([]byte{0})
	h.Write(body)
	h.Write([]byte{0})
	var tsbuf [8]byte
	binary.LittleEndian.PutUint64(tsbuf[:], ts)
	h.Write(tsbuf[:])
	return h.Sum(nil)
}

// acquire grabs an admit slot or returns false on ctx cancellation.
// Tests construct bridges with admit=nil (no limiter); skip the gate
// in that case so handler-only unit tests don't block.
func (b *bridge) acquire(ctx context.Context) bool {
	if b.admit == nil {
		return true
	}
	select {
	case b.admit <- struct{}{}:
		return true
	case <-ctx.Done():
		return false
	}
}

func (b *bridge) release() {
	if b.admit == nil {
		return
	}
	<-b.admit
}

// ---------------------------------------------------------------------------
// /health — liveness probe
// ---------------------------------------------------------------------------

func (b *bridge) health(ctx context.Context) *zap.Message {
	pingCtx, cancel := context.WithTimeout(ctx, 2*time.Second)
	defer cancel()

	row := b.ch.QueryRow(pingCtx, "SELECT 1")
	var v uint8
	if err := row.Scan(&v); err != nil {
		return respondJSON(http.StatusServiceUnavailable, map[string]string{
			"status": "unhealthy",
			"error":  err.Error(),
		})
	}
	if v != 1 {
		return respondJSON(http.StatusServiceUnavailable, map[string]string{
			"status": "unhealthy",
			"error":  fmt.Sprintf("SELECT 1 returned %d", v),
		})
	}
	return respondJSON(http.StatusOK, map[string]string{
		"status":  "ok",
		"service": "hanzo-datastore",
	})
}

// ---------------------------------------------------------------------------
// /query — SELECT and produce NDJSON rows
// ---------------------------------------------------------------------------

type queryReq struct {
	SQL      string        `json:"sql"`
	Args     []interface{} `json:"args,omitempty"`
	Database string        `json:"database,omitempty"`
}

func (b *bridge) query(ctx context.Context, body []byte) *zap.Message {
	var req queryReq
	if err := json.Unmarshal(body, &req); err != nil {
		// Strict JSON only — the deleted bridge's "raw bytes as SQL"
		// fallback was an auth-free SQL surface (Red finding #1). All
		// callers ship JSON; refuse anything else.
		return respondJSON(http.StatusBadRequest, map[string]string{"error": "invalid JSON: " + err.Error()})
	}
	if strings.TrimSpace(req.SQL) == "" {
		return respondJSON(http.StatusBadRequest, map[string]string{"error": "missing sql"})
	}

	qctx := ctx
	if req.Database != "" {
		qctx = clickhouse.Context(qctx, clickhouse.WithSettings(clickhouse.Settings{
			"database": req.Database,
		}))
	}

	rows, err := b.ch.Query(qctx, req.SQL, req.Args...)
	if err != nil {
		return respondJSON(http.StatusBadRequest, map[string]string{"error": err.Error()})
	}
	defer rows.Close()

	cols := rows.Columns()
	var buf bytes.Buffer
	for rows.Next() {
		vals := make([]interface{}, len(cols))
		ptrs := make([]interface{}, len(cols))
		for i := range vals {
			ptrs[i] = &vals[i]
		}
		if err := rows.Scan(ptrs...); err != nil {
			return respondJSON(http.StatusInternalServerError, map[string]string{"error": err.Error()})
		}
		row := make(map[string]interface{}, len(cols))
		for i, c := range cols {
			row[c] = vals[i]
		}
		line, err := json.Marshal(row)
		if err != nil {
			return respondJSON(http.StatusInternalServerError, map[string]string{"error": err.Error()})
		}
		buf.Write(line)
		buf.WriteByte('\n')
	}
	if err := rows.Err(); err != nil {
		return respondJSON(http.StatusInternalServerError, map[string]string{"error": err.Error()})
	}
	return respondNDJSON(http.StatusOK, buf.Bytes())
}

// ---------------------------------------------------------------------------
// /exec — DDL/DML that returns no rows
// ---------------------------------------------------------------------------

type execReq struct {
	SQL      string        `json:"sql"`
	Args     []interface{} `json:"args,omitempty"`
	Database string        `json:"database,omitempty"`
}

func (b *bridge) exec(ctx context.Context, body []byte) *zap.Message {
	var req execReq
	if err := json.Unmarshal(body, &req); err != nil {
		return respondJSON(http.StatusBadRequest, map[string]string{"error": err.Error()})
	}
	if strings.TrimSpace(req.SQL) == "" {
		return respondJSON(http.StatusBadRequest, map[string]string{"error": "missing sql"})
	}
	qctx := ctx
	if req.Database != "" {
		qctx = clickhouse.Context(qctx, clickhouse.WithSettings(clickhouse.Settings{
			"database": req.Database,
		}))
	}
	if err := b.ch.Exec(qctx, req.SQL, req.Args...); err != nil {
		return respondJSON(http.StatusBadRequest, map[string]string{"error": err.Error()})
	}
	return respondJSON(http.StatusOK, map[string]bool{"ok": true})
}

// ---------------------------------------------------------------------------
// /insert — bulk insert via prepared batch
// ---------------------------------------------------------------------------

type insertReq struct {
	Table    string                   `json:"table"`
	Database string                   `json:"database,omitempty"`
	Rows     []map[string]interface{} `json:"rows"`
}

func (b *bridge) insert(ctx context.Context, body []byte) *zap.Message {
	var req insertReq
	if err := json.Unmarshal(body, &req); err != nil {
		return respondJSON(http.StatusBadRequest, map[string]string{"error": err.Error()})
	}
	if req.Table == "" {
		return respondJSON(http.StatusBadRequest, map[string]string{"error": "missing table"})
	}
	if len(req.Rows) > maxInsertRows {
		return respondJSON(http.StatusBadRequest, map[string]string{
			"error": fmt.Sprintf("rows %d exceeds max %d", len(req.Rows), maxInsertRows),
		})
	}
	if len(req.Rows) == 0 {
		return respondJSON(http.StatusOK, map[string]interface{}{"ok": true, "inserted": 0})
	}

	// Discover column order from the first row. Mixed schemas are not
	// supported — caller is responsible for shaping the batch.
	first := req.Rows[0]
	cols := make([]string, 0, len(first))
	for k := range first {
		cols = append(cols, k)
	}
	// Stable column order for deterministic placeholder mapping.
	sortStrings(cols)

	target := req.Table
	if req.Database != "" {
		target = fmt.Sprintf("`%s`.`%s`", req.Database, req.Table)
	}
	colList := "(`" + strings.Join(cols, "`, `") + "`)"
	stmt := "INSERT INTO " + target + " " + colList

	batch, err := b.ch.PrepareBatch(ctx, stmt)
	if err != nil {
		return respondJSON(http.StatusBadRequest, map[string]string{"error": err.Error()})
	}
	for i, row := range req.Rows {
		vals := make([]interface{}, len(cols))
		for j, c := range cols {
			vals[j] = row[c]
		}
		if err := batch.Append(vals...); err != nil {
			_ = batch.Abort()
			return respondJSON(http.StatusBadRequest, map[string]string{
				"error": fmt.Sprintf("row %d: %s", i, err.Error()),
			})
		}
	}
	if err := batch.Send(); err != nil {
		return respondJSON(http.StatusBadRequest, map[string]string{"error": err.Error()})
	}
	return respondJSON(http.StatusOK, map[string]interface{}{
		"ok":       true,
		"inserted": len(req.Rows),
	})
}

// ---------------------------------------------------------------------------
// Response builders
// ---------------------------------------------------------------------------

// respondJSON encodes data as JSON and packages it as a ZAP response.
// The path/method conveys intent — NDJSON callers use respondNDJSON.
func respondJSON(status int, data interface{}) *zap.Message {
	body, _ := json.Marshal(data)
	return buildResponse(status, body)
}

// respondNDJSON wraps already-encoded NDJSON bytes as a ZAP response.
func respondNDJSON(status int, raw []byte) *zap.Message {
	return buildResponse(status, raw)
}

// buildResponse is the canonical response constructor. Two fields:
// status (0:Uint32), body (4:Bytes). See the const block for the
// rationale on dropping the legacy headers field.
func buildResponse(status int, body []byte) *zap.Message {
	b := zap.NewBuilder(len(body) + 64)
	ob := b.StartObject(12)
	ob.SetUint32(respStatus, uint32(status))
	ob.SetBytes(respBody, body)
	ob.FinishAsRoot()
	msg, err := zap.Parse(b.Finish())
	if err != nil {
		// Self-built message that can't parse is a programming bug — emit
		// a minimal status-only response instead of crashing the bridge.
		fb := zap.NewBuilder(64)
		fob := fb.StartObject(12)
		fob.SetUint32(respStatus, http.StatusInternalServerError)
		fob.FinishAsRoot()
		msg, _ = zap.Parse(fb.Finish())
	}
	return msg
}

// portFromListen accepts ":9999" or "0.0.0.0:9999" — returns the port.
func portFromListen(listen string) (int, error) {
	listen = strings.TrimSpace(listen)
	idx := strings.LastIndex(listen, ":")
	if idx < 0 {
		return 0, errors.New("missing port")
	}
	p, err := strconv.Atoi(listen[idx+1:])
	if err != nil || p <= 0 || p > 65535 {
		return 0, fmt.Errorf("invalid port %q", listen[idx+1:])
	}
	return p, nil
}

// sortStrings is a tiny, allocation-free in-place sort. We avoid pulling
// sort.Strings to keep the binary minimal — and the column lists are
// small enough that the algorithm choice is irrelevant.
func sortStrings(s []string) {
	for i := 1; i < len(s); i++ {
		for j := i; j > 0 && s[j-1] > s[j]; j-- {
			s[j-1], s[j] = s[j], s[j-1]
		}
	}
}
