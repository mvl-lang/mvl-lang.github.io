# The 11 Requirements

MVL enforces eleven properties at compile time. If your code compiles, it satisfies all eleven. No runtime checks needed for these categories — they are *structurally impossible* to violate.

---

## Overview

| # | Requirement | What it prevents | Key mechanism |
|---|-------------|------------------|---------------|
| 1 | Type safety | Impossible states | Algebraic data types |
| 2 | Memory safety | Use-after-free, buffer overflow | Ownership + borrowing |
| 3 | Exhaustive matching | Unhandled cases | Match completeness |
| 4 | Null elimination | Null pointer dereference | `Option[T]` only |
| 5 | Error visibility | Silent error swallowing | `Result[T, E]` required |
| 6 | Ownership | Double-free, resource leaks | Linear types |
| 7 | Effect tracking | Hidden side effects | Effect signatures |
| 8 | Termination | Infinite loops | `total` functions |
| 9 | Data race freedom | Concurrent access bugs | Actor isolation |
| 10 | Refinement types | Out-of-range values | `where` clauses |
| 11 | Information flow | Secret/tainted data leaks | IFC labels |

---

## Requirement 1: Type Safety (ADTs)

**What it prevents:** Invalid state representations, type confusion, stringly-typed code.

**Mechanism:** Algebraic data types (sum types + product types) model exactly the states that can exist. No sentinel values, no magic numbers, no invalid combinations.

```mvl
// Sum type: exactly one of these
enum PaymentStatus {
    Pending,
    Authorized { auth_code: String },
    Captured { amount: Int },
    Failed { reason: String },
}

// The compiler knows all variants. No "unknown status" bugs.
fn handle(status: PaymentStatus) -> String {
    match status {
        Pending => "waiting",
        Authorized { auth_code } => "auth: ".concat(auth_code),
        Captured { amount } => "captured: ".concat(amount.to_string()),
        Failed { reason } => "failed: ".concat(reason),
    }
}
```

**What it replaces:** Stringly-typed status fields, integer codes with magic values, nullable fields that "shouldn't be null in this state."

---

## Requirement 2: Memory Safety

**What it prevents:** Use-after-free, double-free, buffer overflows, dangling pointers.

**Mechanism:** Ownership and borrowing. Every value has exactly one owner. References borrow without ownership transfer. The compiler tracks lifetimes.

```mvl
fn process(data: String) -> Unit {
    let owned: String = data;       // ownership transferred
    consume(owned);                  // ownership transferred to consume()
    // println(owned);               // compile error: owned moved
}

fn read_only(data: ref String) -> Int {
    data.len()                       // borrow, no ownership transfer
}
```

**What it replaces:** Garbage collection overhead, manual malloc/free, reference counting cycles.

---

## Requirement 3: Exhaustive Matching

**What it prevents:** Unhandled cases, forgotten enum variants, incomplete switch statements.

**Mechanism:** `match` expressions must cover all variants. Adding a new variant to an enum causes compile errors everywhere it's matched — forcing you to handle it.

```mvl
enum Direction { North, South, East, West }

fn to_vector(d: Direction) -> (Int, Int) {
    match d {
        North => (0, 1),
        South => (0, -1),
        East => (1, 0),
        // compile error: non-exhaustive match, missing: West
    }
}
```

**What it replaces:** Default cases that swallow unexpected values, "this should never happen" runtime panics.

---

## Requirement 4: Null Elimination

**What it prevents:** Null pointer dereference — the "billion dollar mistake."

**Mechanism:** No null. Optional values use `Option[T]` — either `Some(value)` or `None`. The compiler forces you to handle both cases.

```mvl
fn find_user(id: Int) -> Option[User] {
    // returns Some(user) or None
}

fn greet(id: Int) -> String {
    match find_user(id) {
        Some(user) => "Hello, ".concat(user.name),
        None => "User not found",
    }
    // Cannot forget to handle None — won't compile
}
```

**What it replaces:** Null checks scattered throughout code, `NullPointerException`, undefined behavior.

---

## Requirement 5: Error Visibility

**What it prevents:** Silent error swallowing, ignored return codes, exceptions that propagate invisibly.

**Mechanism:** Fallible operations return `Result[T, E]`. Errors must be explicitly handled or propagated with `?`. No exceptions.

```mvl
fn read_config(path: String) -> Result[Config, IoError] ! FileRead {
    let content: String = read_file(path)?;  // propagates error
    parse_config(content)
}

fn main() -> Unit ! FileRead + Console {
    match read_config("app.toml") {
        Ok(config) => println("loaded"),
        Err(e) => println("error: ".concat(e.message)),
    }
}
```

**What it replaces:** Try/catch blocks, unchecked exceptions, errno that nobody checks.

---

## Requirement 6: Ownership (Linearity)

**What it prevents:** Double-free, resource leaks, use-after-close.

**Mechanism:** Linear types ensure resources are used exactly once. File handles, connections, locks — if you open it, you must close it, exactly once.

```mvl
fn with_file(path: String) -> Result[Unit, IoError] ! FileRead {
    let file: File = open(path)?;    // file opened
    let content: String = read(file); // file consumed (closed after read)
    // read(file);                    // compile error: file already consumed
    Ok(())
}
```

**What it replaces:** try-with-resources, defer statements, RAII (which still allows use-after-move in some languages).

---

## Requirement 7: Effect Tracking

**What it prevents:** Hidden side effects, impure functions pretending to be pure, untraceable I/O.

**Mechanism:** Effects declared in function signatures with `!`. A function that does console I/O must declare `! Console`. Effects propagate — callers must declare effects of callees.

```mvl
fn pure_add(a: Int, b: Int) -> Int {
    a + b  // no effects — pure function
}

fn greet(name: String) -> Unit ! Console {
    println("Hello, ".concat(name))  // Console effect
}

fn main() -> Unit ! Console + FileRead {
    greet("world");                   // must declare Console
    let data = read_file("x.txt")?;   // must declare FileRead
}
```

**What it replaces:** "I/O monad" patterns, implicit global state, functions that secretly write to disk.

---

## Requirement 8: Termination

**What it prevents:** Infinite loops, non-terminating recursion in critical paths.

**Mechanism:** Functions marked `total` must provably terminate. The compiler verifies recursion has decreasing arguments and loops have bounded iterations.

```mvl
total fn factorial(n: Int where n >= 0) -> Int {
    if n == 0 { 1 } else { n * factorial(n - 1) }
    // Compiler proves: n decreases each call, base case exists
}

total fn sum_list(xs: List[Int]) -> Int {
    match xs {
        [] => 0,
        [head, ..tail] => head + sum_list(tail),
    }
    // Compiler proves: list shrinks each call
}
```

**What it replaces:** "Trust me, this terminates" comments, timeout-based recovery, unbounded retry loops.

---

## Requirement 9: Data Race Freedom

**What it prevents:** Concurrent access to shared mutable state, race conditions, heisenbugs.

**Mechanism:** Actor model. Mutable state lives inside actors. Communication via message passing only. No shared memory between actors.

```mvl
actor Counter {
    state count: Int = 0

    msg increment() -> Unit {
        self.count = self.count + 1
    }

    msg get() -> Int {
        self.count
    }
}

fn main() -> Unit ! Spawn {
    let counter: Counter = spawn Counter {};
    counter.increment();  // message send, not direct access
    counter.increment();
    let value: Int = counter.get();
}
```

**What it replaces:** Mutexes, locks, atomic operations, "synchronized" blocks, lock-free data structures.

---

## Requirement 10: Refinement Types

**What it prevents:** Out-of-range values, invalid arguments, violated preconditions.

**Mechanism:** `where` clauses on types. The compiler proves constraints at compile time using an SMT solver.

```mvl
fn divide(a: Int, b: Int where b != 0) -> Int {
    a / b  // division by zero impossible
}

fn percentage(p: Int where p >= 0, p <= 100) -> String {
    p.to_string().concat("%")
}

fn main() -> Unit ! Console {
    println(divide(10, 2));     // OK: compiler proves 2 != 0
    // println(divide(10, 0));  // compile error: 0 violates b != 0
    
    let x: Int = 50;
    println(percentage(x));     // OK if compiler can prove 0 <= x <= 100
}
```

**What it replaces:** Runtime validation, assert statements, "throws IllegalArgumentException."

---

## Requirement 11: Information Flow Control

**What it prevents:** Secret data leaking to logs, tainted input reaching SQL queries, PII exposed to analytics.

**Mechanism:** IFC labels on types. Data carries its security label. The compiler tracks information flow and prevents unauthorized release.

```mvl
label Secret
label Tainted

relabel declassify: Secret -> _ audit   // requires audit tag
relabel sanitize: Tainted -> _          // explicit trust boundary

fn process_password(pw: Secret[String]) -> Unit ! Console {
    // println(pw);                      // compile error: Secret cannot flow to Console
    let hash: String = relabel declassify(hash(pw), "AUTH-001");
    println("hash: ".concat(hash));      // OK: declassified with audit trail
}

fn query(input: Tainted[String]) -> String ! Database {
    // execute("SELECT * FROM users WHERE name = " + input);  // compile error
    let safe: String = relabel sanitize(validate(input));
    execute("SELECT * FROM users WHERE name = ".concat(safe))
}
```

**What it replaces:** Manual taint tracking, security reviews, "don't log passwords" policies.

---

## The Compound Effect

Each requirement is valuable alone. Together, they compound:

- **Type safety + exhaustive matching** = impossible states don't compile
- **Null elimination + error visibility** = every failure path is explicit
- **Ownership + effect tracking** = resource management is provable
- **Refinement + IFC** = security properties are types, not policies

The eleven requirements are not a checklist. They are an integrated system where each property reinforces the others.

**Code that compiles is well-formed.** Tests verify it does the right thing — not that it handles nulls, not that it avoids races, not that it tracks secrets. Those are already proven.
