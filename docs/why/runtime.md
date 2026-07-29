# Runtime Observability

The fourth pillar: **observability by default, not by effort.**

MVL programs emit structured telemetry from the moment they start. Logging, audit trails, metrics, and tracing are language-level features — not libraries you bolt on after the fact.

---

## Philosophy

Traditional observability is opt-in. You add a logging library, instrument your code, configure exporters. Most codepaths go unobserved until something breaks.

MVL inverts this. The compiler generates observability hooks. The runtime emits structured data. You opt *out* of what you don't need, not in to what you do.

**Why this matters for LLM-generated code:** The LLM doesn't know which codepaths will be important in production. If observability requires manual instrumentation, LLM-generated code arrives dark — no logs, no traces, no metrics. With default observability, every function the LLM generates is observable from day one.

---

## 1. Structured Logging

MVL logging is structured by default. No string interpolation, no printf formatting — key-value pairs that machines can parse.

```mvl
use std.log.{Logger, default_logger, LogLevel}

fn process_order(order_id: String, amount: Int) -> Result[Unit, OrderError] ! Log {
    let logger: Logger = default_logger();
    
    logger.info("order.received", {
        "order_id": order_id,
        "amount": amount.to_string(),
    });
    
    match validate_order(order_id, amount) {
        Err(e) => {
            logger.error("order.validation_failed", {
                "order_id": order_id,
                "error": e.to_string(),
            });
            Err(e)
        },
        Ok(_) => {
            logger.info("order.processed", {
                "order_id": order_id,
                "status": "success",
            });
            Ok(())
        },
    }
}
```

Output (JSON Lines format):

```json
{"ts":"2026-07-04T10:30:00Z","level":"info","msg":"order.received","order_id":"ORD-123","amount":"5000"}
{"ts":"2026-07-04T10:30:01Z","level":"info","msg":"order.processed","order_id":"ORD-123","status":"success"}
```

### Log Levels

| Level | Use case |
|-------|----------|
| `trace` | Fine-grained debugging (usually disabled) |
| `debug` | Development diagnostics |
| `info` | Normal operations |
| `warn` | Recoverable issues |
| `error` | Failures requiring attention |

### Package Context

Every log entry automatically includes package metadata from `std.runtime`:

```json
{
  "ts": "2026-07-04T10:30:00Z",
  "level": "info",
  "msg": "order.received",
  "pkg": "myapp",
  "version": "0.1.0",
  "purl": "pkg:mvl/myapp@0.1.0",
  "order_id": "ORD-123"
}
```

This links every log entry to its SBOM — you can trace any production log back to the exact build and dependency set.

---

## 2. IFC Audit Trails

Information Flow Control labels track sensitive data through your program. When data crosses a trust boundary via `relabel`, MVL emits an audit record.

```mvl
use std.ifc.{Tainted, trust}

label PCI

relabel tokenize: PCI -> _ audit   // audit tag required

fn process_card(card: PCI[String]) -> String {
    let token: String = relabel tokenize(card, "PAYMENT-001");
    token
}
```

Every `relabel` with `audit` emits a structured audit event:

```json
{
  "ts": "2026-07-04T10:30:00Z",
  "event": "ifc.relabel",
  "from_label": "PCI",
  "to_label": "_",
  "relabel": "tokenize",
  "audit_tag": "PAYMENT-001",
  "location": "payment.mvl:7:20",
  "pkg": "myapp",
  "version": "0.1.0"
}
```

### Why Audit Tags Matter

The audit tag (`"PAYMENT-001"`) is a human-readable identifier for *why* this trust boundary crossing happened. During security review or incident response, you can:

```bash
# Find all PCI data releases
grep '"from_label":"PCI"' audit.log

# Find all releases for a specific business reason
grep '"audit_tag":"PAYMENT-001"' audit.log

# Count releases by tag
jq -r '.audit_tag' audit.log | sort | uniq -c
```

The compiler enforces that every `audit` relabel has a tag. You can't accidentally declassify data without documenting why.

---

## 3. Metrics

MVL exposes Prometheus-compatible metrics for runtime observability.

```mvl
use std.metrics.{Counter, Gauge, Histogram, register}

fn main() -> Unit ! Metrics {
    let requests: Counter = register("http_requests_total", "Total HTTP requests");
    let active: Gauge = register("http_active_connections", "Active connections");
    let latency: Histogram = register("http_request_duration_seconds", "Request latency");
    
    // In request handler:
    requests.inc();
    active.inc();
    let start: Instant = now();
    
    // ... handle request ...
    
    active.dec();
    latency.observe(start.elapsed_seconds());
}
```

### Default Metrics

Every MVL program automatically exposes:

| Metric | Type | Description |
|--------|------|-------------|
| `mvl_build_info` | Gauge | Build metadata (version, commit) |
| `mvl_start_time_seconds` | Gauge | Process start timestamp |
| `mvl_ifc_relabels_total` | Counter | IFC boundary crossings by label |
| `mvl_gc_pause_seconds` | Histogram | GC pause durations (if applicable) |

### Exposition

```bash
$ curl http://localhost:9090/metrics
# HELP mvl_build_info Build information
# TYPE mvl_build_info gauge
mvl_build_info{name="myapp",version="0.1.0",commit="a1b2c3d"} 1

# HELP http_requests_total Total HTTP requests
# TYPE http_requests_total counter
http_requests_total 12847

# HELP mvl_ifc_relabels_total IFC boundary crossings
# TYPE mvl_ifc_relabels_total counter
mvl_ifc_relabels_total{from="PCI",to="_",relabel="tokenize"} 3421
```

---

## 4. Distributed Tracing

For microservices architectures, MVL supports distributed tracing with W3C Trace Context propagation.

```mvl
use std.trace.{Span, start_span, current_span}
use pkg.http.{Request, Response}

fn handle_request(req: Request) -> Response ! Trace + Net {
    let span: Span = start_span("handle_request", {
        "http.method": req.method,
        "http.path": req.path,
    });
    
    // Nested span for database call
    let db_span: Span = start_span("db.query", {
        "db.statement": "SELECT * FROM users",
    });
    let users: List[User] = query_users();
    db_span.end();
    
    // Nested span for external call
    let ext_span: Span = start_span("external.api", {
        "http.url": "https://api.example.com/validate",
    });
    let valid: Bool = validate_external(users);
    ext_span.end();
    
    span.end();
    Response::ok(users.to_json())
}
```

### Trace Context Propagation

When calling external services, trace context propagates automatically:

```mvl
use pkg.http.{Client, Request}

fn call_downstream(client: Client, req: Request) -> Response ! Net + Trace {
    // Trace headers (traceparent, tracestate) are injected automatically
    client.send(req)
}
```

Incoming requests extract trace context from headers, continuing the distributed trace across service boundaries.

### Exporters

Configure trace export in `mvl.toml`:

```toml
[telemetry.trace]
exporter = "otlp"              # OpenTelemetry Protocol
endpoint = "http://jaeger:4317"
sample_rate = 0.1              # Sample 10% of traces
```

---

## 5. Effect-Based Telemetry

Observability in MVL is tracked through the effect system. Functions that emit telemetry declare it in their signature:

```mvl
fn pure_compute(x: Int) -> Int {
    x * 2  // no effects — no telemetry
}

fn logged_compute(x: Int) -> Int ! Log {
    let logger = default_logger();
    logger.debug("computing", {"input": x.to_string()});
    x * 2
}

fn traced_compute(x: Int) -> Int ! Trace {
    let span = start_span("compute", {});
    let result = x * 2;
    span.end();
    result
}

fn fully_observed(x: Int) -> Int ! Log + Trace + Metrics {
    // All three observability effects
}
```

**Why this matters:** You can see at a glance which functions emit telemetry. A function without `! Log` cannot secretly log. A function without `! Metrics` cannot secretly emit metrics. Observability is visible in types, not hidden in implementations.

---

## Configuration

Runtime telemetry is configured in `mvl.toml`:

```toml
[telemetry]
# Global enable/disable
enabled = true

[telemetry.log]
level = "info"                 # Minimum log level
format = "json"                # json or logfmt
output = "stderr"              # stderr, stdout, or file path

[telemetry.audit]
enabled = true
output = "audit.log"           # Separate file for IFC audit trail

[telemetry.metrics]
enabled = true
endpoint = "0.0.0.0:9090"      # Prometheus scrape endpoint

[telemetry.trace]
enabled = true
exporter = "otlp"
endpoint = "http://localhost:4317"
sample_rate = 1.0              # 100% in dev, lower in prod
```

### Environment Overrides

All settings can be overridden via environment variables:

```bash
MVL_LOG_LEVEL=debug mvl run myapp.mvl
MVL_TRACE_SAMPLE_RATE=0.01 mvl run myapp.mvl  # 1% sampling in prod
MVL_METRICS_ENABLED=false mvl run myapp.mvl   # Disable metrics
```

---

## The Observability Contract

Every MVL program upholds these guarantees:

1. **Structured by default** — All telemetry is machine-parseable
2. **Context-rich** — Package info, trace IDs, IFC labels included automatically
3. **Effect-visible** — Telemetry operations declared in function signatures
4. **Audit-complete** — Every IFC boundary crossing is logged with justification
5. **Correlatable** — Logs, traces, metrics, and SBOM link together

**The LLM generates the code. The compiler ensures it's observable.** When something goes wrong in production, you have the data to understand why — even if the LLM didn't anticipate the failure mode.
