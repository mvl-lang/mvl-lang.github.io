# Language Overview

MVL is a statically typed, compiled language designed around one principle: **if it compiles, eleven structural properties are proven.**

The compiler is not a suggestion engine. Every program that passes `mvl check` carries a machine-checked guarantee across memory safety, termination, effect tracking, information flow, and more — with zero runtime overhead.

---

## The Eleven Requirements

Every MVL program is verified against eleven requirements at compile time.

| # | Requirement | What the compiler prevents |
|---|-------------|---------------------------|
| **1** | **Type safety** | Invalid states, type confusion, stringly-typed APIs |
| **2** | **Memory safety** | Use-after-free, double-free, buffer overflows |
| **3** | **Exhaustive matching** | Unhandled enum variants, forgotten cases |
| **4** | **Null elimination** | Null pointer dereferences — `Option[T]` is the only optional |
| **5** | **Error visibility** | Silent error swallowing — `Result[T, E]` forces explicit handling |
| **6** | **Ownership** | Resource leaks, double-free, use-after-close |
| **7** | **Effect tracking** | Hidden I/O, impure functions pretending to be pure |
| **8** | **Termination** | Infinite loops and non-terminating recursion |
| **9** | **Data race freedom** | Concurrent access to shared mutable state |
| **10** | **Refinement types** | Out-of-range values, precondition violations |
| **11** | **Information flow control** | Secret data leaking to logs, tainted input reaching the database |

Requirements 1–6 are established (the Rust lineage). Requirements 7–11 were previously too annotation-heavy to be practical. MVL makes them economical: the language surface is small, annotations are explicit, and the LLM carries the annotation burden.

---

## How it Works

```
source.mvl
    │
    ▼
mvl check          ← 11 requirements verified here
    │
    ├─ FAIL → compile error with location, requirement number, explanation
    │
    └─ PASS → all 11 proven, no runtime overhead
         │
         ▼
    mvl build → binary
```

The compiler runs five phases internally:

| Phase | What happens |
|-------|-------------|
| Parse | LL(1) recursive descent; ≈100 grammar productions |
| Resolve | Module imports, name resolution |
| Check | 11 requirement passes + layered refinement solver (Layers 1–5) |
| Lower | AST → Typed IR → monomorphization |
| Emit | TIR → Rust source → `rustc`, or TIR → LLVM IR → `llc` |

---

## Syntax at a Glance

### Functions

```rust
// Pure function — no effects declared, no side effects allowed
total fn add(a: Int, b: Int) -> Int { a + b }

// Effectful function — Console is declared in the signature
partial fn greet(name: String) -> Unit ! Console {
    println("Hello, ".concat(name))
}

// With pre/postconditions
fn safe_divide(a: Float, b: Float) -> Float
    requires b != 0.0
    ensures result * b == a
{
    a / b
}
```

`total` — compiler proves termination. `partial` — may not terminate. Omitted — inferred.

### Types

```rust
// Struct with field-level refinements
type Port = struct {
    number: Int where self > 0 && self < 65536,
}

// Enum with named-field variants
type Shape = enum {
    Circle { radius: Float where self > 0.0 },
    Rectangle { width: Float, height: Float },
    Point,
}

// Type alias with a refinement predicate
type PositiveInt = Int where self > 0
```

### Effects

Effects are declared in function signatures with `!`. Callers must declare every effect their callees use — nothing is hidden.

```rust
fn read_config(path: String) -> Result[Config, IoError] ! FileRead {
    let raw: String = read_file(path)?;   // ? propagates the error
    parse_config(raw)
}

fn main() -> Unit ! Console + FileRead {
    let cfg: Config = read_config("app.toml")?;
    println(cfg.host)
}
```

### Information Flow

```rust
fn handle(input: Tainted[String]) -> String {
    relabel trust(input, "XSS-validated")   // explicit, audited declassification
}

// Compiler rejects Secret flowing to Console — compile error:
// println(secret_value)
// ^^^^^^^^^^^^^^^^^^^^^^^^^^ Secret[String] cannot flow to effect Console
```

### Actors

```rust
actor Counter {
    count: Int

    pub fn increment(val n: Int) { self.count = self.count + n }
    fn get() -> Int { self.count }   // private sync helper
}
```

`pub fn` = asynchronous message handler. State is actor-private. No shared memory, no data races.

---

## Why Small?

MVL is deliberately the smallest general-purpose language by surface area.

| Metric | MVL | C++ | Java |
|--------|-----|-----|------|
| Keywords | ~45 | 97 | 67 |
| Statement forms | ~10 | 50+ | 30+ |
| Grammar productions | ~100 | 500+ | 500+ |

A smaller surface means fewer feature interactions for the verifier, higher LLM interpolation accuracy, and one canonical way to express each concept. Every feature in MVL was added only if it increases the number of properties the compiler can verify.

---

## Next Steps

- [Design Principles](principles.md) — the reasoning behind every choice
- [Examples](examples.md) — programs demonstrating the 11 requirements
- [Language Reference](../docs/reference.md) — complete syntax and type system
