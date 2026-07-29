# Examples

These examples are drawn from the MVL corpus and test suite. Each demonstrates a specific set of the eleven compile-time requirements.

---

## Type safety and exhaustive matching

Requirements 1 and 3 — algebraic data types and exhaustive match.

```mvl
type Attempts = Int where self >= 0

type AuthError = enum {
    NotFound,
    InvalidPassword,
    AccountLocked(Attempts),
    TokenExpired,
}

total fn error_message(e: AuthError) -> String {
    match e {
        AuthError::NotFound          => "user not found",
        AuthError::InvalidPassword   => "wrong password",
        AuthError::AccountLocked(attempts) => {
            let n: Int = attempts;
            "locked after ".concat(n.to_string()).concat(" attempts")
        },
        AuthError::TokenExpired      => "token expired",
    }
    // Adding a fifth variant to AuthError causes a compile error here.
    // The compiler forces every variant to be handled explicitly.
}
```

The `Attempts` type is `Int where self >= 0` — a refinement enforced at construction. You cannot pass `-1` to `AuthError::AccountLocked`; the compiler rejects it.

---

## Null elimination and error visibility

Requirements 4 and 5 — `Option[T]` and `Result[T, E]`.

```mvl
use std.io.{read_file, IoError}
use std.ifc.{Tainted, trust}

fn parse_port(s: String) -> Option[Int] {
    match s.parse_int() {
        Ok(n)   => if n > 0 && n < 65536 { Some(n) } else { None },
        Err(_)  => None,
    }
}

partial fn load_config(path: String) -> Result[Int, IoError] ! FileRead {
    let raw: Tainted[String] = read_file(path)?;      // ? propagates IoError up
    let text: String = relabel trust(raw, "CONFIG-FILE");
    match parse_port(text.trim()) {
        Some(port) => Ok(port),
        None       => Err(IoError::Other("invalid port number")),
    }
}
```

`read_file` returns `Result[Tainted[String], IoError]` — you cannot use the value without handling both the I/O error *and* the Tainted label. The `?` operator propagates the error; `relabel trust` releases the Tainted with an audit tag that appears in the assurance report.

---

## Effect tracking

Requirement 7 — effects are declared in signatures, not hidden.

```mvl
use std.io.{read_file, IoError}
use std.ifc.{Tainted, trust}

// Pure function — no effects, provably free of side effects
total fn celsius_to_fahrenheit(c: Float) -> Float {
    c * 1.8 + 32.0
}

// Has Console effect — must be declared
fn print_temperature(c: Float) -> Unit ! Console {
    let f: Float = celsius_to_fahrenheit(c);   // pure call — no effect
    println(f.to_string())
}

// Has both Console and FileRead — both must be declared
partial fn report_temperature(path: String) -> Result[Unit, IoError] ! Console + FileRead {
    let raw: Tainted[String] = read_file(path)?;
    let text: String = relabel trust(raw, "TEMP-FILE");
    match text.trim().parse_float() {
        Err(_) => { println("invalid temperature"); Ok(()) },
        Ok(c)  => { print_temperature(c); Ok(()) },
    }
}
```

The compiler rejects a function that calls `println` but does not declare `! Console`. Effects propagate upward — every caller of an effectful function must declare each effect it inherits.

---

## Termination checking

Requirement 8 — `total` functions are proven to terminate.

```mvl
// total: compiler proves this terminates via structural recursion
total fn factorial(n: Int where self >= 0) -> Int {
    if n <= 1 { 1 } else { n * factorial(n - 1) }
}

// total with an explicit loop variant
total fn sum_list(xs: List[Int]) -> Int {
    let acc: ref Int = 0;
    let i:   ref Int = 0;
    let n:   Int     = xs.len();
    while i < n decreases n - i {
        acc = acc + xs.get(i).unwrap_or(0);
        i   = i + 1;
    }
    acc
}

// partial: the loop count depends on runtime input, so termination is not proven
partial fn count_down(start: Int) -> Int {
    let x: ref Int = start;
    while x > 0 {
        x = x - 1;
    }
    x
}
```

`decreases n - i` is the loop variant: the compiler verifies it strictly decreases on each iteration and is bounded below by zero. `count_down` omits the variant — MVL accepts it because it is declared `partial`, meaning termination is not proven.

---

## Refinement types

Requirement 10 — value constraints proven at compile time.

```mvl
type PositiveInt = Int where self > 0
type Port        = Int where self > 0 && self < 65536

total fn validate_port(p: Int) -> Option[Port] {
    if p > 0 && p < 65536 {
        let port: Port = p;   // flow-sensitive: p is provably in-range here
        Some(port)
    } else {
        None
    }
}

fn main() -> Unit ! Console {
    // Compiler proves the literal 8080 satisfies Port's constraint
    let default_port: Port = 8080;

    // Compile error — -1 does not satisfy Port where self > 0
    // let bad_port: Port = -1;

    println(default_port.to_string());
}
```

The layered solver (Layers 1–5: literal, flow-sensitive, interval, Cooper arithmetic, Z3 SMT) discharges most constraints at compile time. When static proof is not possible, a runtime check is inserted automatically and logged in the assurance report.

---

## Information flow control

Requirement 11 — secret data cannot reach unauthorized sinks.

```mvl
use std.ifc.{Tainted, Secret, trust, release}
use std.log.{Logger, default_logger}

type UserId = String

// External input arrives as Tainted — cannot reach the DB without validation
total fn validate_id(raw_id: Tainted[String]) -> UserId {
    // Compile error would occur if we returned raw_id directly.
    // Correct: release the Tainted with an audit tag after validation.
    relabel trust(raw_id, "USER-ID-VALIDATE")
}

// Secret data cannot be logged without explicit declassification.
fn log_masked_id(secret_id: Secret[String]) -> Unit ! Log {
    // Compile error would occur here:
    //   let logger: Logger = default_logger();
    //   logger.info("user", {"id": secret_id})   // Secret cannot flow to Log
    //
    // Correct: release the Secret with an audit tag (assurance record).
    let bare: String = relabel release(secret_id, "MASK-FOR-LOGGING");
    let logger: Logger = default_logger();
    logger.info("user", {"id_tail": bare})
}
```

Every `relabel` call carries an audit tag. Each call appears in the assurance report — a complete inventory of every point where a trust boundary is crossed. `trust` releases `Tainted → bare`; `release` releases `Secret → bare`; both require the audit tag.

---

## Data race freedom via actors

Requirement 9 — no shared mutable state, no races.

```mvl
actor RequestCounter {
    // Private mutable state — visible only inside this actor.
    total_requests: Int

    // Private helper (synchronous, never called from outside).
    fn log_count(n: Int) -> Unit ! Console {
        println("total requests: ".concat(n.to_string()))
    }

    // Behavior (async message handler).
    //   val route  — immutable String; safe to send across the mailbox boundary
    //   Actor behaviors always return Unit — fire-and-forget.
    pub fn record(val route: String) ! Console {
        self.total_requests = self.total_requests + 1
        log_count(self.total_requests)
    }
}

fn main() -> Unit ! Console + Actor {
    // `actor Name { fields }` creates and returns a handle to a fresh actor.
    let counter: RequestCounter = actor RequestCounter { total_requests: 0 };

    // Message sends — the calls return immediately; the actor's runtime
    // serialises the mailbox so concurrent sends cannot race.
    counter.record("/users");
    counter.record("/users");
    counter.record("/health")
}
```

The actor's fields are accessible only through its behaviors. Behaviors are async and return `Unit` — you send a message, the actor processes it later. Concurrent senders cannot race because the mailbox serialises delivery. Requirement 9 is structural, not disciplinary.

---

## Ownership and resource safety

Requirement 6 — resources used exactly once.

```mvl
use std.io.{open, close, write, Fd, IoError, Path}

partial fn append_line(p: Path, line: String) -> Result[Unit, IoError] ! Console {
    let fd: Fd = open(p)?;

    // write takes fd by value — after this call, fd is consumed.
    let _: Result[Unit, IoError] = write(fd, line.concat("\n"));

    // Compile error: fd was already consumed by write.
    // close(fd);

    Ok(())
}
```

`Fd` is passed by value: after `write(fd, ...)`, the compiler tracks that `fd` has moved and rejects any further use. A file descriptor that reaches the end of its scope without being consumed is a compile error — no resource leak possible.

---

## Layering requirements together

A small pipeline showing requirements 1, 5, 7, and 10 layered on top of each other. See [`mvl-lang/examples/crud_api`](https://github.com/mvl-lang/examples/tree/main/crud_api) for the full REST handler.

```mvl
type CreateUserRequest = struct {
    name:  String,
    email: String,
}

type CreateError = enum {
    ValidationFailed(String),
    Conflict(String),
}

// Stubs for the demo — in real code these come from a DB package.
fn validate(name: String, email: String) -> Result[CreateUserRequest, CreateError] {
    if name.len() == 0 {
        Err(CreateError::ValidationFailed("name required"))
    } else {
        if email.len() == 0 {
            Err(CreateError::ValidationFailed("email required"))
        } else {
            Ok(CreateUserRequest { name: name, email: email })
        }
    }
}

fn db_insert(req: CreateUserRequest) -> Result[Int, CreateError] {
    Ok(42)   // stub — real impl talks to SQLite and can return Conflict
}

pub fn create_user(name: String, email: String) -> Result[Int, CreateError] ! Console {
    let req: CreateUserRequest = validate(name, email)?;
    let new_id: Int            = db_insert(req)?;
    println("created id=".concat(new_id.to_string()));
    Ok(new_id)
}
```

The compiler verifies: all error paths handled (Requirement 5), effects declared (`! Console`, Requirement 7), no null (Requirement 4), and every enum variant matched (Requirement 3).

---

## Example Programs in the Repository

Two sets of runnable example programs live in the MVL GitHub organisation.

### [`mvl-lang/mvl` — stdlib-only examples](https://github.com/mvl-lang/mvl/tree/main/examples)

These examples use only the standard library — no external packages required. Run any of them with `mvl run examples/<name>/main.mvl`.

| Example | What it shows |
|---------|--------------|
| [`access_control`](https://github.com/mvl-lang/mvl/tree/main/examples/access_control) | RBAC decision logic — type-safe roles and permissions |
| [`actor_pingpong`](https://github.com/mvl-lang/mvl/tree/main/examples/actor_pingpong) | Two actors exchanging messages — actor model basics |
| [`actor_trading`](https://github.com/mvl-lang/mvl/tree/main/examples/actor_trading) | Order book matching engine — actors with shared domain state |
| [`bzip`](https://github.com/mvl-lang/mvl/tree/main/examples/bzip) | Bitstream packing — low-level byte manipulation with refinements |
| [`config_server`](https://github.com/mvl-lang/mvl/tree/main/examples/config_server) | Layered configuration — defaults → TOML → env → CLI |
| [`csv_transactions`](https://github.com/mvl-lang/mvl/tree/main/examples/csv_transactions) | CSV parsing with `std.csv` — IFC-aware file I/O |
| [`flight_clearance`](https://github.com/mvl-lang/mvl/tree/main/examples/flight_clearance) | Safety-critical dispatch — exhaustive match over clearance states |
| [`hipaa_healthcare`](https://github.com/mvl-lang/mvl/tree/main/examples/hipaa_healthcare) | HIPAA-style data labeling — `Secret` types in database operations |
| [`log_analyzer`](https://github.com/mvl-lang/mvl/tree/main/examples/log_analyzer) | Log severity classification — total functions over structured input |
| [`log_to_file`](https://github.com/mvl-lang/mvl/tree/main/examples/log_to_file) | Structured logging to file — `std.log` + `std.io` |
| [`medical_triage`](https://github.com/mvl-lang/mvl/tree/main/examples/medical_triage) | Emergency triage scoring — refinements on medical priority types |
| [`pci_payment`](https://github.com/mvl-lang/mvl/tree/main/examples/pci_payment) | PCI-DSS card processing — `Secret` labels on card data, relabel audit trail |
| [`snake_game`](https://github.com/mvl-lang/mvl/tree/main/examples/snake_game) | Snake game logic — actors, refinements on board coordinates |
| [`task_pipeline`](https://github.com/mvl-lang/mvl/tree/main/examples/task_pipeline) | Pipeline with error propagation — `Result` chaining across stages |

### [`mvl-lang/examples` — package-based examples](https://github.com/mvl-lang/examples)

These examples use extension packages (`pkg.*`). Run `mvl install` in the example directory first, then `mvl run main.mvl`.

| Example | Packages used | What it shows |
|---------|--------------|--------------|
| [`crud_api`](https://github.com/mvl-lang/examples/tree/main/crud_api) | `pkg-http`, `pkg-rest`, `pkg-sqlite`, `pkg-health`, `pkg-metrics`, `pkg-trace` | Full REST API — routing, SQLite CRUD, K8s health, Prometheus metrics, distributed tracing |
| [`actor_webserver`](https://github.com/mvl-lang/examples/tree/main/actor_webserver) | `pkg-http` | Actor-per-request HTTP server — concurrency model for production traffic |
| [`sqlite_basic`](https://github.com/mvl-lang/examples/tree/main/sqlite_basic) | `pkg-sqlite` | SQLite open, schema init, insert, query — database basics |
| [`zmq_hello`](https://github.com/mvl-lang/examples/tree/main/zmq_hello) | `pkg-zmq` | ZMTP 3.x PUSH/PULL and PUB/SUB — zero-dependency messaging |
| [`snake_game`](https://github.com/mvl-lang/examples/tree/main/snake_game) | `pkg-tui` | Snake with a terminal UI — raw mode, ANSI rendering, keyboard input |
| [`anthropic_chat`](https://github.com/mvl-lang/examples/tree/main/anthropic_chat) | `pkg-anthropic` | Claude Messages API client — `Secret[String]` API keys, IFC-safe chat |

---

## Next Steps

- [Language Reference](../docs/reference.md) — full syntax specification
- [Extension Packages](../docs/packages.md) — all available `pkg.*` packages
- [Getting Started](../getting-started.md) — run your first program
