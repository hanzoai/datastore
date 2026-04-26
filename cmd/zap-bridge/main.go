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
//
//	Response fields:
//	  respStatus  = 0   Uint32  HTTP-style status code
//	  respBody    = 4   Bytes   JSON or NDJSON response
//	  respHeaders = 8   Bytes   JSON-encoded headers
//
// Sub-methods (path):
//
//	/health  liveness probe — returns 200 iff ClickHouse responds to SELECT 1.
//	/query   {sql, database?, format?} — runs SELECT, returns NDJSON.
//	/exec    {sql, database?} — runs a non-SELECT, returns {ok:true}.
//	/insert  {table, database?, rows:[{...}]} — bulk insert via JSONEachRow.
//	/tables  {database?} — list tables, returns JSON array.
//
// Default fallback: a non-empty body with no recognised path is treated as
// a query (matches the deleted bridge for back-compat).
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
//
// Response fields:
//   respStatus = 0  Uint32  HTTP-style status code
//   respBody   = 4  Bytes   JSON or NDJSON payload
//
// Note: the deleted hanzo/zap/internal/datastore/proxy.go also wrote a
// `respHeaders` Bytes field at offset 8. That layout is broken — Bytes
// occupies offset+8 inline, so a Bytes at 4 (occupies 4..11) collides
// with another Bytes at 8 (occupies 8..15). The collision overwrote the
// body's length with the headers' deferred-offset placeholder, producing
// responses where reading `body` returned body+headers concatenated.
// No caller ever read respHeaders (verified across hanzo/orm/db/zap.go
// and hanzo/cloud/object/zap.go), so we drop it. New callers that need
// content-type negotiation should use the path: /query → NDJSON, all
// others → JSON. Keeping respBody at offset 4 preserves bytewise
// compatibility with existing readers.
const (
	fieldPath = 4
	fieldBody = 12

	respStatus = 0
	respBody   = 4
)

// config gathers all runtime knobs. All have safe defaults — zero-flag
// invocation is the production path.
type config struct {
	listen      string // ZAP listen, default :9999
	clickhouse  string // ClickHouse native TCP, default 127.0.0.1:9000
	user        string // CH username, default "default"
	password    string // CH password, default ""
	database    string // default DB, default "default"
	nodeID      string // ZAP NodeID, default hostname or "datastore"
	serviceType string // ZAP service, default "_hanzo._tcp"
}

func loadConfig() config {
	cfg := config{
		listen:      env("ZAP_LISTEN", ":9999"),
		clickhouse:  env("DATASTORE_NATIVE_ADDR", "127.0.0.1:9000"),
		user:        env("DATASTORE_USER", "default"),
		password:    env("DATASTORE_PASSWORD", ""),
		database:    env("DATASTORE_DB", "default"),
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
	return cfg
}

func env(k, def string) string {
	if v := os.Getenv(k); v != "" {
		return v
	}
	return def
}

func main() {
	cfg := loadConfig()
	logger := slog.New(slog.NewJSONHandler(os.Stderr, &slog.HandlerOptions{Level: slog.LevelInfo})).
		With("component", "zap-bridge")

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
		MaxOpenConns:     10,
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
func (b *bridge) handle(ctx context.Context, _ string, msg *zap.Message) *zap.Message {
	root := msg.Root()
	if root.IsNull() {
		return respondJSON(http.StatusBadRequest, map[string]string{"error": "empty request"})
	}
	path := root.Text(fieldPath)
	body := root.Bytes(fieldBody)

	switch path {
	case "/health":
		return b.health(ctx)
	case "/query":
		return b.query(ctx, body)
	case "/exec":
		return b.exec(ctx, body)
	case "/insert":
		return b.insert(ctx, body)
	case "/tables":
		return b.tables(ctx, body)
	default:
		// Compat with deleted proxy: an unrecognised path with a non-empty
		// body is interpreted as a query. This preserves the historical
		// behaviour of the zap-sidecar so older clients keep working.
		if len(body) > 0 {
			return b.query(ctx, body)
		}
		return respondJSON(http.StatusNotFound, map[string]string{"error": "unknown path: " + path})
	}
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
		// Compat: if the body isn't JSON, treat the whole thing as raw SQL.
		req.SQL = string(body)
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
// /tables — list tables in a database
// ---------------------------------------------------------------------------

type tablesReq struct {
	Database string `json:"database,omitempty"`
}

func (b *bridge) tables(ctx context.Context, body []byte) *zap.Message {
	req := tablesReq{Database: b.cfg.database}
	if len(body) > 0 {
		_ = json.Unmarshal(body, &req)
	}
	if req.Database == "" {
		req.Database = b.cfg.database
	}
	rows, err := b.ch.Query(ctx, "SELECT name FROM system.tables WHERE database = ?", req.Database)
	if err != nil {
		return respondJSON(http.StatusBadRequest, map[string]string{"error": err.Error()})
	}
	defer rows.Close()

	var names []string
	for rows.Next() {
		var n string
		if err := rows.Scan(&n); err != nil {
			return respondJSON(http.StatusInternalServerError, map[string]string{"error": err.Error()})
		}
		names = append(names, n)
	}
	if err := rows.Err(); err != nil {
		return respondJSON(http.StatusInternalServerError, map[string]string{"error": err.Error()})
	}
	return respondJSON(http.StatusOK, map[string]interface{}{
		"database": req.Database,
		"tables":   names,
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
