// Copyright (c) 2026 Hanzo Industries Inc.
// SPDX-License-Identifier: Apache-2.0
//
// Unit tests for the zap-bridge ZAP→ClickHouse translator.
//
// These tests construct a `bridge` with a fake executor (no real
// ClickHouse), build real ZAP request messages with the canonical wire
// shape, drive them through `bridge.handle`, and decode the ZAP responses
// back into structured form for assertion.
//
// They cover the two opcodes called out in the spec:
//   - Health  → /health  → 200 when CH responds, 503 when it doesn't
//   - Query   → /query   → NDJSON rows on success, 400 on SQL error
//
// Insert and exec are exercised by the "/insert end-to-end" and
// "/exec round-trip" tests because they share the same wire path.

package main

import (
	"context"
	"encoding/json"
	"errors"
	"fmt"
	"strings"
	"testing"
	"time"

	"github.com/ClickHouse/clickhouse-go/v2/lib/column"
	"github.com/ClickHouse/clickhouse-go/v2/lib/driver"
	"github.com/luxfi/zap"
)

// ---------------------------------------------------------------------------
// Fakes
// ---------------------------------------------------------------------------

// fakeExec is the test double for the bridge.executor interface. Each
// call returns the next preset response, or an error if exhausted —
// programmer error in the test, not a real failure mode.
type fakeExec struct {
	queryRows func(ctx context.Context, query string, args ...any) (driver.Rows, error)
	queryRow  func(ctx context.Context, query string, args ...any) driver.Row
	exec      func(ctx context.Context, query string, args ...any) error
	prepare   func(ctx context.Context, query string, opts ...driver.PrepareBatchOption) (driver.Batch, error)
}

func (f *fakeExec) Query(ctx context.Context, query string, args ...any) (driver.Rows, error) {
	if f.queryRows == nil {
		return nil, fmt.Errorf("fakeExec.Query not configured (query=%s)", query)
	}
	return f.queryRows(ctx, query, args...)
}
func (f *fakeExec) QueryRow(ctx context.Context, query string, args ...any) driver.Row {
	if f.queryRow == nil {
		return &fakeRow{err: fmt.Errorf("fakeExec.QueryRow not configured (query=%s)", query)}
	}
	return f.queryRow(ctx, query, args...)
}
func (f *fakeExec) Exec(ctx context.Context, query string, args ...any) error {
	if f.exec == nil {
		return fmt.Errorf("fakeExec.Exec not configured (query=%s)", query)
	}
	return f.exec(ctx, query, args...)
}
func (f *fakeExec) PrepareBatch(ctx context.Context, query string, opts ...driver.PrepareBatchOption) (driver.Batch, error) {
	if f.prepare == nil {
		return nil, fmt.Errorf("fakeExec.PrepareBatch not configured (query=%s)", query)
	}
	return f.prepare(ctx, query, opts...)
}

// fakeRow implements driver.Row.
type fakeRow struct {
	err   error
	value uint8
}

func (r *fakeRow) Err() error                { return r.err }
func (r *fakeRow) ScanStruct(dest any) error { return r.err }
func (r *fakeRow) Scan(dest ...any) error {
	if r.err != nil {
		return r.err
	}
	if len(dest) == 0 {
		return errors.New("no destinations")
	}
	if p, ok := dest[0].(*uint8); ok {
		*p = r.value
		return nil
	}
	return fmt.Errorf("fakeRow.Scan: unsupported destination %T", dest[0])
}

// fakeRows implements driver.Rows for a slice-of-string-maps fixture.
type fakeRows struct {
	cols []string
	data []map[string]any
	idx  int
	err  error
}

func (r *fakeRows) Next() bool {
	if r.err != nil {
		return false
	}
	r.idx++
	return r.idx <= len(r.data)
}
func (r *fakeRows) Scan(dest ...any) error {
	if r.idx == 0 || r.idx > len(r.data) {
		return errors.New("Scan called out of range")
	}
	if len(dest) != len(r.cols) {
		return fmt.Errorf("Scan: %d dests, %d cols", len(dest), len(r.cols))
	}
	row := r.data[r.idx-1]
	for i, c := range r.cols {
		v := row[c]
		// Bridge calls Scan with []*any so each dest is a *interface{}.
		if p, ok := dest[i].(*any); ok {
			*p = v
			continue
		}
		return fmt.Errorf("Scan col %s: unsupported destination %T", c, dest[i])
	}
	return nil
}
func (r *fakeRows) ScanStruct(any) error      { return errors.New("not implemented") }
func (r *fakeRows) Columns() []string         { return r.cols }
func (r *fakeRows) ColumnTypes() []driver.ColumnType {
	return nil
}
func (r *fakeRows) Totals(...any) error { return nil }
func (r *fakeRows) Close() error        { return nil }
func (r *fakeRows) Err() error          { return r.err }

// fakeBatch implements driver.Batch — captures Append calls so tests can
// assert what was sent.
type fakeBatch struct {
	rows [][]any
	sent bool
}

func (b *fakeBatch) Abort() error              { return nil }
func (b *fakeBatch) Send() error               { b.sent = true; return nil }
func (b *fakeBatch) Flush() error              { return nil }
func (b *fakeBatch) IsSent() bool              { return b.sent }
func (b *fakeBatch) Rows() int                 { return len(b.rows) }
func (b *fakeBatch) Columns() []column.Interface { return nil }
func (b *fakeBatch) Column(int) driver.BatchColumn { return nil }
func (b *fakeBatch) AppendStruct(any) error    { return errors.New("not implemented") }
func (b *fakeBatch) Append(v ...any) error {
	cp := make([]any, len(v))
	copy(cp, v)
	b.rows = append(b.rows, cp)
	return nil
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

// testHMACKey is the shared key used by every test bridge + builder so
// HMAC verification passes by default. Tests that probe auth failure
// build their own bridges with a different key.
var testHMACKey = []byte("0123456789abcdef0123456789abcdef")

// buildRequest constructs a real ZAP message with the canonical
// (path, body, ts, hmac) shape — exactly what hanzo/orm/db/zap.go sends.
// Signs with testHMACKey; tests that need an unsigned/wrong-key request
// use buildRequestRaw.
func buildRequest(t *testing.T, path string, body []byte) *zap.Message {
	t.Helper()
	return buildRequestRaw(t, path, body, testHMACKey, time.Now().UnixMilli())
}

// buildRequestRaw is the underlying builder — exposed so adversarial
// tests can craft messages with bad keys, stale timestamps, or missing
// MACs. ts is Unix milliseconds. If key is nil, the HMAC field is left
// empty (unsigned frame).
func buildRequestRaw(t *testing.T, path string, body []byte, key []byte, ts int64) *zap.Message {
	t.Helper()
	b := zap.NewBuilder(len(body) + 256)
	obj := b.StartObject(objectFixedSize)
	obj.SetText(fieldPath, path)
	obj.SetBytes(fieldBody, body)
	obj.SetUint64(fieldTS, uint64(ts))
	if key != nil {
		mac := computeHMAC(key, path, body, uint64(ts))
		obj.SetBytes(fieldHMAC, mac)
	}
	obj.FinishAsRoot()
	// Sender sets flags = msgType << 8 — but we use the wire-level 8-bit
	// projection because shifting a uint16 = 302 left by 8 overflows at
	// compile time. This matches what orm/db/zap.go produces at runtime
	// (silent overflow). See main.go:msgTypeDatastoreWire for the rationale.
	msg, err := zap.Parse(b.FinishWithFlags(msgTypeDatastoreWire << 8))
	if err != nil {
		t.Fatalf("buildRequest: parse self-built message: %v", err)
	}
	return msg
}

// decodeResponse reads a response message back into (status, body).
// Headers are not transmitted — see main.go for rationale.
func decodeResponse(t *testing.T, msg *zap.Message) (uint32, []byte) {
	t.Helper()
	if msg == nil {
		t.Fatal("decodeResponse: nil message")
	}
	root := msg.Root()
	if root.IsNull() {
		t.Fatal("decodeResponse: null root")
	}
	return root.Uint32(respStatus), root.Bytes(respBody)
}

// newTestBridge builds a bridge wired to the supplied fake — no real
// ClickHouse, no ZAP listener. Just the handler logic. admit is left
// nil so handler tests don't block on the semaphore; security tests
// that exercise the gate construct their own bridge.
func newTestBridge(fe *fakeExec) *bridge {
	return &bridge{
		cfg: config{database: "test", hmacKey: testHMACKey},
		ch:  fe,
	}
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

func TestHealth_OK(t *testing.T) {
	fe := &fakeExec{
		queryRow: func(ctx context.Context, q string, args ...any) driver.Row {
			if q != "SELECT 1" {
				t.Errorf("Health: unexpected query %q", q)
			}
			return &fakeRow{value: 1}
		},
	}
	b := newTestBridge(fe)
	resp := b.handle(context.Background(), "", buildRequest(t, "/health", nil))
	status, body := decodeResponse(t, resp)
	if status != 200 {
		t.Fatalf("status: got %d, want 200", status)
	}
	var parsed map[string]string
	if err := json.Unmarshal(body, &parsed); err != nil {
		t.Fatalf("body: %v (raw=%q)", err, body)
	}
	if parsed["status"] != "ok" {
		t.Errorf("body.status: got %q, want ok", parsed["status"])
	}
	if parsed["service"] != "hanzo-datastore" {
		t.Errorf("body.service: got %q, want hanzo-datastore", parsed["service"])
	}
}

func TestHealth_DownReturns503(t *testing.T) {
	fe := &fakeExec{
		queryRow: func(ctx context.Context, q string, args ...any) driver.Row {
			return &fakeRow{err: errors.New("connection refused")}
		},
	}
	b := newTestBridge(fe)
	resp := b.handle(context.Background(), "", buildRequest(t, "/health", nil))
	status, body := decodeResponse(t, resp)
	if status != 503 {
		t.Fatalf("status: got %d, want 503", status)
	}
	if !strings.Contains(string(body), "connection refused") {
		t.Errorf("body: %q does not surface upstream error", body)
	}
}

func TestQuery_RoundTripNDJSON(t *testing.T) {
	fe := &fakeExec{
		queryRows: func(ctx context.Context, q string, args ...any) (driver.Rows, error) {
			if !strings.Contains(q, "events") {
				t.Errorf("Query: unexpected SQL %q", q)
			}
			return &fakeRows{
				cols: []string{"id", "name"},
				data: []map[string]any{
					{"id": int64(1), "name": "alpha"},
					{"id": int64(2), "name": "bravo"},
				},
			}, nil
		},
	}
	b := newTestBridge(fe)
	body, _ := json.Marshal(map[string]any{"sql": "SELECT id, name FROM events"})
	resp := b.handle(context.Background(), "", buildRequest(t, "/query", body))
	status, respBytes := decodeResponse(t, resp)
	if status != 200 {
		t.Fatalf("status: got %d, want 200", status)
	}
	lines := strings.Split(strings.TrimRight(string(respBytes), "\n"), "\n")
	if len(lines) != 2 {
		t.Fatalf("rows: got %d, want 2", len(lines))
	}
	var first map[string]any
	if err := json.Unmarshal([]byte(lines[0]), &first); err != nil {
		t.Fatalf("row 0: %v", err)
	}
	if first["name"] != "alpha" {
		t.Errorf("row 0.name: got %v, want alpha", first["name"])
	}
}

func TestQuery_SQLErrorReturns400(t *testing.T) {
	fe := &fakeExec{
		queryRows: func(ctx context.Context, q string, args ...any) (driver.Rows, error) {
			return nil, errors.New("syntax error near 'SLECT'")
		},
	}
	b := newTestBridge(fe)
	body, _ := json.Marshal(map[string]any{"sql": "SLECT 1"})
	resp := b.handle(context.Background(), "", buildRequest(t, "/query", body))
	status, respBytes := decodeResponse(t, resp)
	if status != 400 {
		t.Fatalf("status: got %d, want 400", status)
	}
	if !strings.Contains(string(respBytes), "syntax error") {
		t.Errorf("body: %q does not surface upstream error", respBytes)
	}
}

func TestQuery_MissingSQLReturns400(t *testing.T) {
	b := newTestBridge(&fakeExec{})
	body, _ := json.Marshal(map[string]any{}) // empty
	resp := b.handle(context.Background(), "", buildRequest(t, "/query", body))
	status, _ := decodeResponse(t, resp)
	if status != 400 {
		t.Fatalf("status: got %d, want 400", status)
	}
}

func TestExec_OK(t *testing.T) {
	called := false
	fe := &fakeExec{
		exec: func(ctx context.Context, q string, args ...any) error {
			called = true
			if !strings.Contains(q, "CREATE TABLE") {
				t.Errorf("Exec: unexpected SQL %q", q)
			}
			return nil
		},
	}
	b := newTestBridge(fe)
	body, _ := json.Marshal(map[string]any{"sql": "CREATE TABLE t (a UInt64) ENGINE = Memory"})
	resp := b.handle(context.Background(), "", buildRequest(t, "/exec", body))
	status, _ := decodeResponse(t, resp)
	if status != 200 {
		t.Fatalf("status: got %d, want 200", status)
	}
	if !called {
		t.Error("exec callback never invoked")
	}
}

func TestInsert_AppendsAndSends(t *testing.T) {
	batch := &fakeBatch{}
	fe := &fakeExec{
		prepare: func(ctx context.Context, q string, opts ...driver.PrepareBatchOption) (driver.Batch, error) {
			if !strings.Contains(q, "events") {
				t.Errorf("PrepareBatch: unexpected SQL %q", q)
			}
			// Columns must appear sorted: id, name (alphabetical).
			if !strings.Contains(q, "(`id`, `name`)") {
				t.Errorf("PrepareBatch: column order wrong: %q", q)
			}
			return batch, nil
		},
	}
	b := newTestBridge(fe)
	body, _ := json.Marshal(map[string]any{
		"table": "events",
		"rows": []map[string]any{
			{"id": 1, "name": "a"},
			{"id": 2, "name": "b"},
		},
	})
	resp := b.handle(context.Background(), "", buildRequest(t, "/insert", body))
	status, respBytes := decodeResponse(t, resp)
	if status != 200 {
		t.Fatalf("status: got %d, want 200; body=%s", status, respBytes)
	}
	if !batch.sent {
		t.Error("batch.Send was not called")
	}
	if len(batch.rows) != 2 {
		t.Errorf("batch.rows: got %d, want 2", len(batch.rows))
	}
	// Sorted columns → row layout is [id, name].
	if batch.rows[0][0] != float64(1) { // JSON unmarshal → float64 for ints
		t.Errorf("batch row 0 col 0: got %v, want 1", batch.rows[0][0])
	}
	if batch.rows[0][1] != "a" {
		t.Errorf("batch row 0 col 1: got %v, want \"a\"", batch.rows[0][1])
	}
}

func TestUnknownPathReturns404(t *testing.T) {
	b := newTestBridge(&fakeExec{})
	resp := b.handle(context.Background(), "", buildRequest(t, "/nope", nil))
	status, _ := decodeResponse(t, resp)
	if status != 404 {
		t.Fatalf("status: got %d, want 404", status)
	}
}

// Red finding #1 follow-up: the deleted zap-sidecar's "unrecognised path
// → query fallback" is auth-free SQL. We removed it. This test pins the
// new behaviour: unknown paths return 404, never fall through.
func TestUnknownPathRejectsBodyFallthrough(t *testing.T) {
	called := false
	fe := &fakeExec{
		queryRows: func(ctx context.Context, q string, args ...any) (driver.Rows, error) {
			called = true
			return &fakeRows{cols: []string{"v"}, data: []map[string]any{{"v": int64(1)}}}, nil
		},
	}
	b := newTestBridge(fe)
	body, _ := json.Marshal(map[string]any{"sql": "SELECT 1 AS v"})
	resp := b.handle(context.Background(), "", buildRequest(t, "/legacy", body))
	status, _ := decodeResponse(t, resp)
	if status != 404 {
		t.Fatalf("status: got %d, want 404 (unknown path must NOT fall through)", status)
	}
	if called {
		t.Error("executor was invoked — unknown path fell through to query")
	}
}

// ---------------------------------------------------------------------------
// Pure helpers
// ---------------------------------------------------------------------------

func TestPortFromListen(t *testing.T) {
	cases := []struct {
		in      string
		want    int
		wantErr bool
	}{
		{":9999", 9999, false},
		{"0.0.0.0:9999", 9999, false},
		{"127.0.0.1:1234", 1234, false},
		{"", 0, true},
		{"nope", 0, true},
		{":bad", 0, true},
		{":0", 0, true},
		{":99999", 0, true},
	}
	for _, c := range cases {
		got, err := portFromListen(c.in)
		if (err != nil) != c.wantErr {
			t.Errorf("portFromListen(%q) err=%v wantErr=%v", c.in, err, c.wantErr)
			continue
		}
		if got != c.want {
			t.Errorf("portFromListen(%q) = %d, want %d", c.in, got, c.want)
		}
	}
}

func TestSortStrings(t *testing.T) {
	in := []string{"c", "a", "b"}
	sortStrings(in)
	if in[0] != "a" || in[1] != "b" || in[2] != "c" {
		t.Errorf("sort: got %v, want [a b c]", in)
	}
}
