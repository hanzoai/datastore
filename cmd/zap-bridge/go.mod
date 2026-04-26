// zap-bridge is a per-package Go module — the existing C++/CMake build of
// hanzo-datastore stays untouched. This module is built only by the
// Dockerfile.hanzo `zap-builder` stage.
module github.com/hanzoai/datastore/cmd/zap-bridge

go 1.26.1

require (
	github.com/ClickHouse/clickhouse-go/v2 v2.30.0
	github.com/luxfi/zap v0.2.1
)

require (
	github.com/ClickHouse/ch-go v0.61.5 // indirect
	github.com/andybalholm/brotli v1.1.1 // indirect
	github.com/cenkalti/backoff v2.2.1+incompatible // indirect
	github.com/go-faster/city v1.0.1 // indirect
	github.com/go-faster/errors v0.7.1 // indirect
	github.com/google/uuid v1.6.0 // indirect
	github.com/grandcat/zeroconf v1.0.0 // indirect
	github.com/klauspost/compress v1.17.7 // indirect
	github.com/luxfi/mdns v0.1.0 // indirect
	github.com/miekg/dns v1.1.62 // indirect
	github.com/paulmach/orb v0.11.1 // indirect
	github.com/pierrec/lz4/v4 v4.1.21 // indirect
	github.com/pkg/errors v0.9.1 // indirect
	github.com/segmentio/asm v1.2.0 // indirect
	github.com/shopspring/decimal v1.4.0 // indirect
	go.opentelemetry.io/otel v1.26.0 // indirect
	go.opentelemetry.io/otel/trace v1.26.0 // indirect
	golang.org/x/mod v0.18.0 // indirect
	golang.org/x/net v0.30.0 // indirect
	golang.org/x/sync v0.7.0 // indirect
	golang.org/x/sys v0.26.0 // indirect
	golang.org/x/tools v0.22.0 // indirect
	gopkg.in/yaml.v3 v3.0.1 // indirect
)
