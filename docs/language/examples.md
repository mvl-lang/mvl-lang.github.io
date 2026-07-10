# Examples

These examples are drawn from the MVL corpus and test suite. Each demonstrates a specific set of the eleven compile-time requirements.

---

## Type safety and exhaustive matching

Requirements 1 and 3 — algebraic data types and exhaustive match.

```mvl
type AuthError = enum {
    NotFound,
    InvalidPassword,
    AccountLocked { attempts: Int where self >= 0 },
    TokenExpired,
}

total fn error_message(e: AuthError) -> String {
    match e {
        NotFound          => "user not found",
        InvalidPassword   => "wrong password",
        AccountLocked { attempts } =>
            "locked after ".concat(attempts.to_string()).concat(" attempts"),
        TokenExpired      => "token expired",
    }
    // Adding a fifth variant to AuthError causes a compile error here.
    // The compiler forces every variant to be handled explicitly.
}
```

The `AccountLocked` variant carries a field with a refinement — `attempts >= 0` is enforced at construction. You cannot create an `AccountLocked { attempts: -1 }`.

---

## Null elimination and error visibility

Requirements 4 and 5 — `Option[T]` and `Result[T, E]`.

```mvl
use std.io.{read_file, IoError}

fn parse_port(s: String) -> Option[Int] {
    match s.parse_int() {
        None    => None,
        Some(n) => if n > 0 && n < 65536 { Some(n) } else { None },
    }
}

partial fn load_config(path: String) -> Result[Int, IoError] ! FileRead {
    let raw: String = read_file(path)?;   // ? propagates IoError up
    match parse_port(raw.trim()) {
        Some(port) => Ok(port),
        None       => Err(IoError::InvalidData("invalid port number")),
    }
}
```

`read_file` returns `Result[String, IoError]` — you cannot use the value without handling the error. The `?` operator propagates the error and requires `! FileRead` in the caller's signature.

---

## Effect tracking

Requirement 7 — effects are declared in signatures, not hidden.

```mvl
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
partial fn report_temperature(path: String) -> Unit ! Console + FileRead {
    let raw: String = read_file(path)?;
    match raw.trim().parse_float() {
        None    => println("invalid temperature"),
        Some(c) => print_temperature(c),
    }
}
```

The compiler rejects a function that calls `println` but does not declare `! Console`. Effects propagate upward — every caller of an effectful function must declare that effect.

---

## Termination checking

Requirement 8 — `total` functions are proven to terminate.

```mvl
// total: compiler proves this terminates via structural recursion
total fn factorial(n: Int where self >= 0) -> Int {
    if n <= 1 { 1 } else { n * factorial(n - 1) }
}

// total with explicit loop variant
total fn sum_list(xs: List[Int]) -> Int {
    let acc: ref Int = 0;
    let i: ref Int = 0;
    while i < xs.len() decreases xs.len() - i {
        acc = acc + xs.get(i).unwrap_or(0);
        i = i + 1;
    }
    acc
}

// partial: while true loop — may not terminate, compiler accepts but does not prove
partial fn server_loop(listener: TcpListener) -> Unit ! Net {
    while true {
        match tcp_accept(listener) {
            Ok(stream)  => handle(stream),
            Err(_)      => return,
        }
    }
}
```

`decreases xs.len() - i` is the loop variant: the compiler verifies it strictly decreases on each iteration and is bounded below by zero.

---

## Refinement types

Requirement 10 — value constraints proven at compile time.

```mvl
type PositiveInt = Int where self > 0
type Port        = Int where self > 0 && self < 65536

total fn validate_port(p: Int) -> Option[Port] {
    if p > 0 && p < 65536 { Some(p) } else { None }
}

// Compiler proves the literal 8080 satisfies Port's constraint
let default_port: Port = 8080;

// Compile error — -1 does not satisfy Port where self > 0
// let bad_port: Port = -1;

fn connect(host: String, port: Port) -> Result[TcpStream, NetError] ! Net {
    tcp_connect(host, port)  // port is statically known to be valid
}
```

The layered solver (Layers 1–5: trivial, interval, symbolic, Cooper arithmetic, Z3 SMT) discharges most constraints at compile time. When static proof is not possible, a runtime check is inserted automatically and shown in `mvl prove`.

---

## Information flow control

Requirement 11 — secret data cannot reach unauthorized sinks.

```mvl
use std.ifc.{Tainted, Secret}

// External input arrives as Tainted — cannot reach the database without validation
partial fn handle_request(
    raw_id: Tainted[String],
    val db: SqliteDb,
) -> Result[User, String] ! DB {
    // Compile error: Tainted[String] cannot flow to DB without sanitization
    // db_get_user(db, raw_id)

    // Correct: sanitize first, then use
    let id: String = relabel sanitize(raw_id, "id-validation");
    db_get_user(db, id)
}

// Secret data cannot be logged without explicit declassification
fn log_masked_id(secret_id: Secret[String]) -> Unit ! Log {
    // Compile error: Secret[String] cannot flow to Log
    // logger.info("user", {"id": secret_id})

    // Correct: declassify with an audit tag (recorded in the assurance report)
    let last4: String = relabel trust(secret_id, "mask-for-logging");
    logger.info("user", {"id_tail": last4})
}
```

Every `relabel` call with its audit tag appears in the assurance report — a complete inventory of every point where a trust boundary is crossed.

---

## Data race freedom via actors

Requirement 9 — no shared mutable state, no races.

```mvl
actor RequestCounter {
    total_requests: Int
    by_route: Map[String, Int]

    // pub fn = async behavior; parameters must be sendable (val / iso / value types)
    pub fn record(val route: String) {
        self.total_requests = self.total_requests + 1;
        let prev: Int = self.by_route.get(route).unwrap_or(0);
        self.by_route = self.by_route.insert(route, prev + 1);
    }

    pub fn snapshot() -> Map[String, Int] {
        self.by_route
    }
}

partial fn main() -> Unit ! Console + Spawn {
    let counter: RequestCounter = spawn RequestCounter {
        total_requests: 0,
        by_route: Map[String, Int]::new(),
    };

    // Message sends — never direct field access
    counter.record("/users");
    counter.record("/users");
    counter.record("/health");

    let counts: Map[String, Int] = counter.snapshot();
    println(counts.get("/users").unwrap_or(0).to_string())
}
```

The actor's fields are accessible only through its methods. Concurrent senders cannot race — messages are serialised by the actor runtime. Requirement 9 is structural, not disciplinary.

---

## Ownership and resource safety

Requirement 6 — resources used exactly once.

```mvl
partial fn process_file(path: String) -> Result[Unit, IoError] ! FileRead + FileWrite {
    let file: FileHandle = open_file(path, FileMode::ReadWrite)?;

    // file is moved here — cannot use it again after this point
    let contents: String = read_all(file)?;

    // Compile error: file was already consumed by read_all
    // close_file(file);

    // The compiler tracks that file was moved into read_all;
    // read_all is responsible for closing it.
    Ok(())
}
```

`FileHandle` is a linear type. The compiler tracks every move. A file handle that reaches the end of its scope without being consumed is a compile error — no resource leak possible.

---

## Layering requirements together

A realistic HTTP handler using requirements 1, 4, 5, 7, 10, and 11 together:

```mvl
use models::{User, CreateUserRequest}
use pkg.rest.json.{json_ok_str, json_error, json_created_str,
                   body_obj, json_field_string, http_bad_request}

pub partial fn create_user_handler(
    val db:      SqliteDb,
    val logger:  Logger,
    val auditor: AuditLogger,
    val req:     Request,
) -> Response ! DB + Log + Audit {
    // Parse body — returns Result, ? propagates the error response
    let obj:   JsonObject = match body_obj(req) {
        Err(e) => return json_error(e),
        Ok(o)  => o,
    };
    let name:  String = match json_field_string(obj, "name") {
        Err(e) => return json_error(e),
        Ok(n)  => n,
    };
    let email: String = match json_field_string(obj, "email") {
        Err(e) => return json_error(e),
        Ok(e)  => e,
    };

    // Create user — returns Result[Int, String]
    match db_create_user(db, CreateUserRequest { name: name, email: email }) {
        Err(msg) => {
            let _: Result[Unit, IoError] = auditor.emit(deny("api", "users", msg));
            json_error(http_bad_request(msg))
        },
        Ok(new_id) => {
            logger.info("created", {"id": new_id.to_string()});
            let _: Result[Unit, IoError] = auditor.emit(
                modify("api", "user:".concat(new_id.to_string()), "create")
            );
            json_created_str(new_id.to_string())
        },
    }
}
```

The compiler verifies: all error paths handled, effects declared, no null, no hidden I/O, no unchecked casts.

---

## Next Steps

- [Language Reference](../docs/reference.md) — full syntax specification
- [Getting Started](../getting-started.md) — run your first program
- [Build Assurance](../why/build-assurance.md) — what the assurance report contains
