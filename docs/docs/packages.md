# Extension Packages

Extension packages provide functionality beyond the standard library — HTTP servers, databases, observability, messaging, TLS, and more. Every package's public API satisfies all eleven requirements; `mvl check` verifies it before you can use it.

All packages are hosted in the [mvl-lang GitHub organisation](https://github.com/mvl-lang).

---

## Installing Packages

Declare dependencies in `mvl.toml`:

```toml
[dependencies]
pkg-http    = { git = "https://github.com/mvl-lang/pkg-http",    tag = "v1.2.0" }
pkg-sqlite  = { git = "https://github.com/mvl-lang/pkg-sqlite",  tag = "v0.2.3" }
pkg-metrics = { git = "https://github.com/mvl-lang/pkg-metrics", tag = "v0.3.0" }
```

Then install and verify:

```bash
mvl install        # fetches, verifies hash, caches under .mvl/pkg/
mvl check main.mvl # verifies your code + all package APIs together
```

The lock file (`mvl.lock`) pins every dependency to an exact commit and SHA-256 hash. `mvl install` verifies the hash before unpacking — supply chain integrity is built in.

---

## Available Packages

### [`pkg-http`](https://github.com/mvl-lang/pkg-http) — HTTP Server

> MVL HTTP package — request parsing, response building, routing, REST helpers

```mvl
use pkg.http.{Request, Response, Router, HttpMethod,
              new_router, route, dispatch, parse_request, serialize_response}
```

Provides a synchronous HTTP server suitable for microservices. Routing is pure — `new_router()` and `route(r, method, path, name)` return new `Router` values. The actual I/O (`tcp_read_request`, `tcp_write`) stays in your code with explicit `! Net` effects.

```toml
pkg-http = { git = "https://github.com/mvl-lang/pkg-http", tag = "v1.2.0" }
```

---

### [`pkg-rest`](https://github.com/mvl-lang/pkg-rest) — REST JSON Helpers

> MVL REST client — typed JSON POST/GET over TLS

```mvl
use pkg.rest.json.{json_ok_str, json_created_str, json_no_content, json_error,
                   param_int, body_obj, json_field_string, json_str,
                   http_not_found, http_bad_request, http_internal_error}
```

JSON response builders and request parsers for REST APIs. Works alongside `pkg-http`. All functions return `Result` or `Response` — no panics on malformed input.

```toml
pkg-rest = { git = "https://github.com/mvl-lang/pkg-rest", tag = "v1.1.0" }
```

---

### [`pkg-sqlite`](https://github.com/mvl-lang/pkg-sqlite) — SQLite Database

> MVL sqlite package — wraps rusqlite behind a fully-verified MVL API

```mvl
use pkg.sqlite.{SqliteDb, SqliteError, open, execute, query, query_scalar, close}
use std.db.{DbValue}
```

Opens a file-backed SQLite database and exposes `execute`, `query`, and `query_scalar`. All operations return `Result`. Parameterised queries use `DbValue` — no string interpolation, no injection.

```mvl
// Insert with bound parameters — safe by construction
execute(db, "INSERT INTO users (name, email) VALUES (?, ?)", [
    DbValue::Text(req.name),
    DbValue::Text(req.email),
])?;
```

```toml
pkg-sqlite = { git = "https://github.com/mvl-lang/pkg-sqlite", tag = "v0.2.3" }
```

---

### [`pkg-health`](https://github.com/mvl-lang/pkg-health) — Health Checks

> MVL health check package — liveness, readiness, component health types

```mvl
use pkg.health.{HealthStatus, HealthReport, ComponentHealth, make_report, health_to_response}
```

Implements the three-endpoint K8s health check pattern:

- `/health` — full report with component status
- `/health/live` — liveness probe (always 200 if the process is running)
- `/health/ready` — readiness probe (200 if all components are healthy)

```toml
pkg-health = { git = "https://github.com/mvl-lang/pkg-health", tag = "v0.3.0" }
```

---

### [`pkg-metrics`](https://github.com/mvl-lang/pkg-metrics) — Prometheus Metrics

> MVL metrics package — counters, gauges, histograms with effect tracking

```mvl
use pkg.metrics.{effect Metric, Metrics, new_metrics, start_prometheus_exporter}
```

Prometheus-compatible metrics with a custom `Metric` effect. Metric operations declare `! Metric` — the effect system makes observability explicit, not hidden.

```mvl
metrics.counter_inc("http_requests_total", {"method": "GET", "route": "/users"});
```

Serves the `/metrics` endpoint for scraping by Prometheus, Grafana Agent, or VictoriaMetrics.

```toml
pkg-metrics = { git = "https://github.com/mvl-lang/pkg-metrics", tag = "v0.3.0" }
```

---

### [`pkg-trace`](https://github.com/mvl-lang/pkg-trace) — Distributed Tracing

> MVL distributed tracing package — spans, trace context, W3C propagation

```mvl
use pkg.trace.{Trace, Tracer, default_tracer, trace_start, span_start, span_end, span_error, TraceContext}
```

W3C Trace Context compatible distributed tracing. `TraceContext` carries a `trace_id` and `span_id` through your request lifecycle. Spans are emitted to stderr in a structured format compatible with OpenTelemetry collectors.

```mvl
let ctx: TraceContext = trace_start("service.boot");
let span: TraceContext = span_start("handler.create_user", ctx);
// ... work ...
span_end(tracer, span);
```

```toml
pkg-trace = { git = "https://github.com/mvl-lang/pkg-trace", tag = "v0.2.0" }
```

---

### [`pkg-tls`](https://github.com/mvl-lang/pkg-tls) — TLS

> MVL TLS package — TLS 1.3 client via rustls, HTTPS convenience layer

```mvl
use pkg.tls.{TlsStream, tls_connect, tls_close}
```

TLS 1.3 client connections backed by [rustls](https://github.com/rustls/rustls). No deprecated cipher suites, no legacy TLS. The `! Net` effect covers both plain TCP and TLS connections — the type system distinguishes them; the effect system tracks them uniformly.

```toml
pkg-tls = { git = "https://github.com/mvl-lang/pkg-tls", tag = "v0.1.0" }
```

---

### [`pkg-zmq`](https://github.com/mvl-lang/pkg-zmq) — ZeroMQ-Style Messaging

> MVL ZeroMQ-style messaging — REQ/REP, PUB/SUB, PUSH/PULL over TCP

```mvl
use pkg.zmq.{ZmqSocket, ZmqSocketType, ZmqError,
             zmtp_handshake_server, zmtp_handshake_client,
             zmq_send, zmq_recv, zmq_error_msg}
```

Implements the [ZMTP 3.x](https://rfc.zeromq.org/spec/37/) wire protocol natively in MVL — no libzmq dependency. Supports REQ/REP, PUSH/PULL, and PUB/SUB patterns over plain TCP. Effects: `! Net`.

```toml
pkg-zmq = { git = "https://github.com/mvl-lang/pkg-zmq", tag = "v0.2.0" }
```

---

### [`pkg-tui`](https://github.com/mvl-lang/pkg-tui) — Terminal UI

> MVL terminal UI package — raw mode, ANSI styles, keyboard input

```mvl
use pkg.tui.{Terminal, Style, Color, Key, enter_raw_mode, exit_raw_mode,
             clear_screen, move_cursor, read_key}
```

Raw terminal mode, ANSI styling, cursor control, and keyboard input for building interactive CLI tools and dashboards. Effects: `! Console`.

```toml
pkg-tui = { git = "https://github.com/mvl-lang/pkg-tui", tag = "v0.1.0" }
```

---

### [`pkg-anthropic`](https://github.com/mvl-lang/pkg-anthropic) — Claude SDK

> Anthropic Claude SDK for MVL — typed Messages API client with IFC security

```mvl
use pkg.anthropic.{AnthropicClient, Message, Role, Content,
                   create_message, ApiKey}
```

A typed MVL client for the [Anthropic Messages API](https://docs.anthropic.com/en/api/messages). API keys are typed as `Secret[String]` — the IFC system prevents them from leaking to logs or responses without explicit declassification.

```mvl
let key: Secret[String] = relabel classify(api_key_env_var, "anthropic-api-key");
let response: Message = create_message(client, [
    Message { role: Role::User, content: Content::Text("Hello, Claude") }
])?;
```

```toml
pkg-anthropic = { git = "https://github.com/mvl-lang/pkg-anthropic", tag = "v0.1.0" }
```

---

## Package Security Model

Every package in the `mvl-lang` organisation follows the same rules:

- The public API (everything not in `internal/`) satisfies all 11 requirements
- `extern` blocks are confined to `internal/` and require `extern-rationale` in `mvl.toml`
- All native dependencies are declared in `[native]` or `[c-native]`
- The lock file pins exact versions and SHA-256 hashes — `mvl install` verifies before unpacking
- `mvl audit --supply-chain` checks hash integrity and license compatibility

Third-party packages outside the organisation can be used too — they go through the same `mvl check` verification before your code can import them.

---

## See Also

- [Standard Library](stdlib.md) — `std.*` modules (always available, no install required)
- [Build Assurance](../why/build-assurance.md) — supply chain, SBOM, and license validation
- [Assurance Report](assurance.md) — how to verify package coverage
