# The 11 Compile-Time Properties

**MVL proves these properties before your code runs. If it compiles, all eleven hold. No runtime checks, no trust boundaries, no "should never happen" paths — the violations are structurally impossible.**

---

## Overview

| # | Property | Mechanism | Prevents |
|---|----------|-----------|----------|
| 1 | Type safety | Algebraic data types | Impossible states, type confusion |
| 2 | Memory safety | Ownership + borrowing | Use-after-free, buffer overflow |
| 3 | Exhaustive matching | Match completeness | Unhandled cases |
| 4 | Null elimination | `Option[T]` | Null pointer dereference |
| 5 | Error visibility | `Result[T, E]` | Silent failures |
| 6 | Ownership | Linear types | Resource leaks, double-free |
| 7 | Effect tracking | `! Effect` signatures | Hidden side effects |
| 8 | Termination | `total` / `partial` | Infinite loops |
| 9 | Data race freedom | Actor isolation | Concurrent access bugs |
| 10 | Refinement types | `where` clauses + SMT | Out-of-range values |
| 11 | Information flow | IFC labels | Secret/tainted data leaks |

---

## Property 1: Type Safety (Algebraic Data Types)

The compiler enforces that values match their declared types through sum types (enums) and product types (structs). Algebraic data types model exactly the states that can exist — no sentinel values, no magic numbers, no invalid field combinations. Type confusion, stringly-typed data, and "impossible state" bugs are rejected at compile time.

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

## Property 2: Memory Safety (Ownership + Borrowing)

Every value has exactly one owner; ownership transfers explicitly, and references borrow without taking ownership. The compiler tracks these relationships statically, rejecting use-after-free, double-free, buffer overflows, and dangling pointer access. This replaces garbage collection, manual memory management, and reference counting — with zero runtime overhead.

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

## Property 3: Exhaustive Matching

Pattern matches must cover every variant of an enum or sum type. Adding a new variant causes compile errors at every match site, forcing explicit handling before the code compiles. Default cases that silently swallow unexpected values are forbidden — the compiler demands you name what you handle.

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

## Property 4: Null Elimination

There is no null pointer in MVL; optional values use `Option[T]`, which is either `Some(value)` or `None`. The compiler forces both cases to be handled — you cannot dereference without first proving the value exists. This eliminates null pointer exceptions entirely, pushing optionality into the type system where it is visible and checked.

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

## Property 5: Error Visibility

Fallible operations return `Result[T, E]`, making error paths explicit in the function signature. Callers must handle or propagate errors with `?` — silent swallowing is a compile error. There are no exceptions; every failure mode is visible in the type, and ignored errors do not compile.

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

## Property 6: Ownership (Linear Types)

Resources like file handles, connections, and locks are linear: they must be used exactly once. The compiler tracks consumption — opening a file and never closing it, or closing it twice, both fail to compile. This guarantees resource cleanup without try-with-resources, defer, or destructors that might not run.

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

## Property 7: Effect Tracking

Side effects are declared in function signatures using `! Effect` syntax (e.g., `! Console`, `! FileRead`). A function that performs I/O must declare it; callers must declare effects of their callees. Pure functions have no effect annotation — the absence of `!` is a compiler-enforced purity guarantee.

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

## Property 8: Termination

Functions marked `total` must provably terminate; the compiler verifies that recursive calls have decreasing arguments and loops have bounded iterations. Functions that might not terminate are marked `partial` — the distinction is enforced, not documentary. Critical code paths can require totality, ensuring no infinite loops reach production.

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

## Property 9: Data Race Freedom (Actor Isolation)

Mutable state exists only inside actors; communication between actors is by message passing, never shared memory. The compiler rejects direct access to another actor's state — there is no syntax for it. Race conditions, data corruption from concurrent writes, and heisenbugs are structurally impossible.

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

## Property 10: Refinement Types

Types carry predicates via `where` clauses: `Int where self > 0`, `String where self.len() <= 255`. The compiler discharges these constraints using an SMT solver, proving at compile time that values satisfy their predicates. Division by zero, out-of-bounds access, and precondition violations are caught before the code runs.

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

## Property 11: Information Flow Control

Data carries security labels (`Secret[T]`, `Tainted[T]`) that the compiler tracks through all operations. Secret data cannot flow to public channels (logs, APIs, analytics) without explicit `relabel declassify`, which requires an audit tag. Every trust boundary crossing is statically checked and recorded — taint tracking and secret hygiene are types, not policies.

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

Each property is valuable alone. Together, they compound:

- **Type safety + exhaustive matching** = impossible states don't compile
- **Null elimination + error visibility** = every failure path is explicit
- **Ownership + effect tracking** = resource management is provable
- **Refinement + IFC** = security properties are types, not policies

The eleven properties are not a checklist. They are an integrated system where each property reinforces the others.

**Code that compiles is well-formed.** Tests verify it does the right thing — not that it handles nulls, not that it avoids races, not that it tracks secrets. Those are already proven.
