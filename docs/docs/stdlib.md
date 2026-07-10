# Standard Library

The MVL standard library is organised in three tiers:

| Tier | Prefix | Extern allowed? | Verification |
|------|--------|-----------------|-------------|
| **Core** | `std.*` | Only marked `builtin` | Full — all 11 requirements |
| **Extended packages** | `pkg.*` | In `internal/` with rationale | Public API fully verified |
| **Your code** | *(local)* | With `extern-rationale` in `mvl.toml` | Full |

Everything in `std.*` is either pure MVL or a `builtin` declaration backed by the runtime. Packages (`pkg.*`) are installed via `mvl install` and verified with `mvl check`.

---

## Implicit Prelude (`std.core`)

`std.core` is loaded before any user source without an explicit `use`. The types and functions below are always available:

### Built-in Types

| Type | Description |
|------|-------------|
| `Int` | 64-bit signed integer |
| `Int8`, `Int16`, `Int32`, `Int64` | Fixed-width signed |
| `UInt8`, `UInt16`, `UInt32`, `UInt64` | Fixed-width unsigned |
| `Float`, `Float32`, `Float64` | IEEE 754 floating point |
| `Bool` | `true` / `false` |
| `Char` | Unicode scalar |
| `Byte` | `UInt8` alias |
| `String` | UTF-8 string |
| `Unit` | Single-value type `()` |
| `List[T]` | Growable sequence |
| `Option[T]` | `Some(v)` or `None` |
| `Result[T, E]` | `Ok(v)` or `Err(e)` |
| `Map[K, V]` | Hash map |
| `Set[T]` | Hash set |

### Always-Available Functions

```mvl
println(s: String) -> Unit ! Console
print(s: String)   -> Unit ! Console
eprintln(s: String) -> Unit ! Console
eprint(s: String)   -> Unit ! Console

// Int methods
n.to_string() -> String
n.abs()       -> Int
n.min(other: Int) -> Int
n.max(other: Int) -> Int

// Float methods
f.to_string() -> String
f.floor() -> Float    f.ceil() -> Float    f.round() -> Float
f.sqrt()  -> Float    f.abs()  -> Float
f.to_int() -> Int

// String methods
s.len()              -> Int
s.is_empty()         -> Bool
s.concat(other: String) -> String
s.trim()             -> String
s.split(sep: String) -> List[String]
s.contains(sub: String) -> Bool
s.starts_with(prefix: String) -> Bool
s.ends_with(suffix: String)   -> Bool
s.to_upper() -> String
s.to_lower() -> String
s.parse_int()   -> Option[Int]
s.parse_float() -> Option[Float]

// List methods
xs.len()         -> Int
xs.is_empty()    -> Bool
xs.get(i: Int)   -> Option[T]
xs.push(v: T)    -> Unit          // on ref List[T]
xs.pop()         -> Option[T]     // on ref List[T]
xs.first()       -> Option[T]
xs.last()        -> Option[T]
xs.map(f: fn(T) -> U)    -> List[U]
xs.filter(f: fn(T) -> Bool) -> List[T]
xs.fold(init: U, f: fn(U, T) -> U) -> U
xs.any(f: fn(T) -> Bool)  -> Bool
xs.all(f: fn(T) -> Bool)  -> Bool
xs.find(f: fn(T) -> Bool) -> Option[T]
xs.sort() -> List[T]
xs.concat(other: List[T]) -> List[T]
xs.take(n: Int) -> List[T]

// Map methods
m.get(key: K)         -> Option[V]
m.insert(key: K, v: V) -> Map[K, V]
m.remove(key: K)       -> Map[K, V]
m.contains_key(key: K) -> Bool
m.keys()    -> List[K]
m.values()  -> List[V]
m.len()     -> Int
Map[K, V]::new() -> Map[K, V]

// Option methods
opt.unwrap_or(default: T) -> T
opt.map(f: fn(T) -> U)    -> Option[U]
opt.is_some() -> Bool
opt.is_none() -> Bool
```

---

## Module Reference

### `std.io` — File I/O and stdin

```mvl
use std.io.{read_file, write_file, append_file, delete_file,
            file_exists, path, IoError}
```

| Function | Signature | Effects |
|----------|-----------|---------|
| `read_file` | `(path: String) -> Result[String, IoError]` | `! FileRead` |
| `write_file` | `(path: String, content: String) -> Result[Unit, IoError]` | `! FileWrite` |
| `append_file` | `(path: String, content: String) -> Result[Unit, IoError]` | `! FileWrite` |
| `delete_file` | `(path: String) -> Result[Unit, IoError]` | `! FileWrite` |
| `file_exists` | `(path: String) -> Bool` | `! FileRead` |
| `read_stdin` | `() -> Result[String, IoError]` | `! Console` |
| `stderr` | `() -> FileHandle` | — |

### `std.log` — Structured Logging

```mvl
use std.log.{Logger, default_logger, LogLevel, LogFormat}
```

```mvl
let logger: Logger = default_logger();

logger.debug("event", {"key": "value"})  // ! Log
logger.info("event",  {"key": "value"})  // ! Log
logger.warn("event",  {"key": "value"})  // ! Log
logger.error("event", {"key": "value"})  // ! Log
```

All log calls are structured key-value maps. No string interpolation — values are always typed.

### `std.env` — Process Environment

```mvl
use std.env.{get, set, all, current_dir}
```

| Function | Signature | Effects |
|----------|-----------|---------|
| `get` | `(key: String) -> Option[String]` | `! Env` |
| `set` | `(key: String, val: String) -> Unit` | `! Env` |
| `all` | `() -> Map[String, String]` | `! Env` |
| `current_dir` | `() -> Result[String, IoError]` | `! Env` |

### `std.net` — TCP Networking

```mvl
use std.net.{TcpListener, TcpStream, tcp_listen, tcp_accept,
            tcp_connect, tcp_read_request, tcp_write,
            tcp_close_listener, tcp_close_stream, NetError}
```

All network operations declare `! Net`. Connections are linear types — they must be closed exactly once.

### `std.args` — CLI Argument Parsing

```mvl
use std.args.{parse_args, required, optional, ArgType, ArgValue}

let cli: Map[String, ArgValue] = parse_args([
    required("host", ArgType::Str),
    optional("port", ArgType::Int),
]);
```

The schema is the specification — no code generation, no macros.

### `std.json` — JSON Encode/Decode

```mvl
use std.json.{Value, parse, encode, ParseError}

let json: Result[Value, ParseError] = parse(raw_string);
let out:  String = encode(value);
```

Pure MVL implementation. Returns `Result` — never panics on bad input.

### `std.math` — Numeric Functions

```mvl
use std.math.{floor, ceil, round, sqrt, pow, log, exp, abs,
              sin, cos, tan, PI, E}
```

All functions are pure (`total`, no effects). Floating-point functions follow IEEE 754.

### `std.time` — Time and Duration

```mvl
use std.time.{Instant, DateTime, Duration, now, sleep, format_datetime}

let t: Instant = now();          // ! Clock
sleep(Duration::millis(500));    // ! Clock
```

### `std.crypto` — Hashing and Secure Random

```mvl
use std.crypto.{sha256, sha512, crypto_random_bytes}

let hash:  List[Byte] = sha256(data);    // pure — no effect
let bytes: List[Byte] = crypto_random_bytes(32);  // ! Random
```

### `std.random` — Pseudorandom Numbers

```mvl
use std.random.{random_int, random_float, random_choice}

let n: Int = random_int(1, 100);       // ! Random
let f: Float = random_float();         // ! Random
```

### `std.process` — Subprocess Management

```mvl
use std.process.{spawn_process, Child, ExitStatus, ProcessError}

let child: Child = spawn_process("git", ["status"])?;  // ! ProcessSpawn
let status: ExitStatus = child.wait()?;
```

### `std.audit` — Compliance Audit Trail

```mvl
use std.audit.{AuditLogger, AuditEvent, file_audit_logger,
               modify, access, deny}

let auditor: AuditLogger = file_audit_logger("audit.jsonl");

// Build and emit audit events
let event: AuditEvent = modify("user:alice", "resource:42", "create.user");
let _: Result[Unit, IoError] = auditor.emit(event);            // ! Audit
let _: Result[Unit, IoError] = auditor.emit(event.fail("msg")); // with error
```

### `std.ifc` — User-Defined IFC Labels

```mvl
use std.ifc.{Tainted, Secret, Public}

// Custom label declarations go in your source:
label ApiKey;
relabel trust: ApiKey -> _ audit;
```

### `std.actors` — Fault-Tolerant Actor Supervision

```mvl
use std.actors.{link, monitor, unlink, ActorRef, ExitReason}

// Link two actors: if either dies, the other is notified
link(actor_a, actor_b);

// Monitor without symmetric risk
monitor(supervisor, worker);
```

### `std.collections` — Extended Collection Operations

```mvl
use std.collections.{group_by, zip, enumerate, flatten, chunks}

let grouped: Map[String, List[T]] = group_by(xs, |x: T| key_fn(x));
let pairs:   List[(A, B)]         = zip(as, bs);
```

### `std.config` — Layered Configuration

```mvl
use std.config.{ConfigValue, merge, with_env, from_toml, as_int, as_string}
```

Implements Defaults → TOML → Env → CLI layering. See `examples/crud_api/config.mvl` for a complete example.

### `std.testing` — Test Framework

```mvl
test fn my_test() -> Unit {
    assert(1 + 1 == 2);
    assert_eq(double(5), 10);
    assert_ne(double(5), 11);
}
```

Run with `mvl test file.mvl`. Test functions are marked `test fn` — orthogonal to totality. `pub` is not allowed on test functions.

### `std.pbt` — Property-Based Testing

```mvl
use std.pbt.{gen_int, gen_string, property_check, Shrinkable}

property_check(100, gen_int(0, 1000), |n: Int| {
    assert(double(n) == n + n)
});
```

Generates random inputs, checks the property, and shrinks failing cases.

### `std.runtime` — Build Metadata

```mvl
use std.runtime.{manifest, Manifest}

let m: Manifest = manifest();
logger.info("startup", {
    "app":     m.app_name,
    "version": m.app_version,
    "mvl":     m.mvl_version,
    "digest":  m.source_digest,
});
```

Embeds build-time metadata into the binary: version, MVL version, dependency list, source digest, build date.

---

## Packages (`pkg.*`)

Extended functionality is provided as packages, installed via `mvl install` from `mvl.toml`. Packages are verified with `mvl check`; their public APIs satisfy all 11 requirements.

| Package | What it provides |
|---------|-----------------|
| `pkg.http` | HTTP server, request/response parsing, routing |
| `pkg.rest` | REST JSON helpers — `json_ok`, `json_error`, `param_int`, `body_obj` |
| `pkg.sqlite` | SQLite database — `open`, `execute`, `query`, `query_scalar` |
| `pkg.health` | K8s health check — `HealthReport`, `health_to_response` |
| `pkg.metrics` | Prometheus metrics — `Metrics`, `counter_inc`, `start_prometheus_exporter` |
| `pkg.trace` | Distributed tracing — `Tracer`, `span_start`, `span_end`, `TraceContext` |

Declare dependencies in `mvl.toml`:

```toml
[dependencies]
pkg-http    = { git = "https://github.com/mvl-lang/pkg-http",    tag = "v1.2.0" }
pkg-sqlite  = { git = "https://github.com/mvl-lang/pkg-sqlite",  tag = "v0.2.3" }
pkg-metrics = { git = "https://github.com/mvl-lang/pkg-metrics", tag = "v0.3.0" }
```

Then install: `mvl install`

---

## See Also

- [Language Reference](reference.md) — type system and syntax
- [Assurance Report](assurance.md) — how to verify stdlib and package coverage
- [Build Assurance](../why/build-assurance.md) — supply chain, SBOM, and license validation
