# Design Principles

MVL has nine design principles across two tiers.

- **Tier 1 — Meta principles** are the *why*. Cross-cutting philosophy that guides every decision. Every ADR in the corpus checks its proposal against these.
- **Tier 2 — Structural decisions** are the *what*. Concrete structural choices those principles produced. Each has its own anchor ADR.

Language-level choices like *total by default*, *immutable by default*, *effects in signatures*, *security labels*, *refinement types*, and *actors instead of threads* are **not** listed here as separate principles. They follow from Tier 1 combined with the eleven requirements (#6) — restating them would be redundant. See the "What's not on this list" section below for where they live.

---

## Tier 1 — Meta principles

### 1. Explicit over implicit

No hidden control flow, no implicit conversions, no silent coercion. Every relevant property lives in the signature or the source.

Consequences: no default arguments, no operator overloading, no implicit numeric conversion, no ambient effects, no inference on `let` bindings, no bare `unwrap()`.

**Cited as:** "DP 1" / "Principle 1" across ADR-0017, ADR-0022, ADR-0024, ADR-0025, ADR-0026.

### 2. One syntax per concept

Each concept has exactly one expression. One loop, one branch, one error mechanism, one form of mutation. Regularity beats variety — the LLM benefits from a single pattern, the compiler benefits from fewer cases.

| Concept | The one way |
|---------|-------------|
| Fallible computation | `Result[T, E]` with `?` propagation |
| Optional value | `Option[T]` with `Some(v)` / `None` |
| Mutable binding | `let x: ref T = ...` |
| Side effect | `! EffectName` in signature |
| Error handling | `match` or `?` — never `try/catch` |
| Iteration | `for x in collection` (total) or `while condition` (partial) |
| Generics | `fn name[T](...)` with square brackets |

**Anchors:** ADR-0002, ADR-0004, ADR-0005.

### 3. Vocabulary over syntax

Grow the stdlib, not the grammar. Compression comes from named, typed, verifiable functions the compiler understands — never from sugar it can't see through. The boundary between language and stdlib moves in one direction only: **stdlib grows, language doesn't.**

Consequences: no macros, no string interpolation, no list comprehensions. `format()` and `Map.get()` exist instead.

**Anchors:** ADR-0002 (compression model), `.openspec/language.md`.

### 4. The signature IS the threat model

Effects, IFC labels, ownership, refinements, termination, errors — all visible in the type signature. Reading a signature reveals the whole contract; nothing is ambient.

```rust
pub partial fn transfer(
    from: Secret[String],        // IFC: secret account ID
    amount: Int where self > 0,  // Refinement: must be positive
    val db: SqliteDb,            // Capability: immutable alias, sendable, not consumed
) -> Result[Unit, TransferError] ! DB + Audit  // Effects: database + audit trail
```

Reading the signature tells you what data is sensitive, what values are valid, what I/O the function performs, what can go wrong, and whether it terminates. The compiler enforces every claim.

**Anchors:** ADR-0001, ADR-0004.

### 5. Honest over silent

The compiler must either verify a property or reject the program. Never silently drop, accept, or defer. Post-Postel: parsers may accept multiple syntactic forms; validators must reject invalid input, never coerce it.

Consequences: no lossy default conversions, no silent label drops at stdlib boundaries, no fallback error handling that hides failure. Explicit `declassify` / `sanitize` for label transitions.

**Anchors:** ADR-0024 (label-transparent functions), ADR-0026 (input validation philosophy).

---

## Tier 2 — Structural decisions

### 6. Eleven requirements — no more, no less

*(ADR-0001)*

The compiler verifies exactly eleven properties:

1. Type safety (ADTs)
2. Memory safety
3. Totality (exhaustive match)
4. Null elimination (Option)
5. Error visibility (Result)
6. Ownership (linearity)
7. Effect tracking
8. Termination checking
9. Data race freedom
10. Refinement types
11. Information flow control

Each was chosen because it catches bugs no combination of the other ten catches, can be verified at compile time with acceptable annotation cost, and does not overlap with another requirement. A twelfth requirement (formal deadlock freedom for actors) was considered and rejected on annotation-cost grounds.

**Classical (1–6):** Rooted in 40 years of formal methods and safety-critical practice (MISRA C, DO-178C, IEC 61508, SPARK Ada). Became mainstream through Rust. MVL inherits them.

**Modern (7–11):** Effect tracking, termination, data race freedom, refinement types, and information flow control were theoretically available before MVL but impractical because the annotation burden fell on human developers. With LLMs writing the code, the burden evaporates.

**Instantiates:** #1 (each requirement makes a property explicit in the type), #4 (the requirements *are* the threat model), #5 (each requirement is verified or the program is rejected).

### 7. Language contraction

*(ADR-0002)*

MVL was built by subtraction. Every feature that exists for writability rather than verifiability was removed.

| Feature | Why removed |
|---------|-------------|
| Mutable closures | Prevent capturing `ref` variables; eliminates a class of aliasing bugs |
| List comprehensions | Use `list.map(f).filter(g)` chains |
| Decorators | Use explicit wrapper functions |
| Implicit conversions | Every type boundary is explicit |
| Operator overloading | One meaning per operator; no surprise semantics |
| Default arguments | All parameters are explicit; no hidden state |
| Variadic arguments | Static arities only; prevents unverifiable call sites |
| Macros | No code generation outside the compiler |
| Ternary operator | Use `if expr { a } else { b }` |
| String interpolation | Use `.concat()` — explicit and verifiable |
| Exceptions | `Result[T, E]` only — errors are values, never invisible |
| Null | `Option[T]` only |
| Mutable-by-default bindings | Immutable default, `ref` opts in |
| Global mutable state | All state lives in actor fields or explicit `ref` bindings |
| `break` / `continue` | Loop control flow is explicit via `return` and `while true` |
| Inheritance | Composition only |
| Dynamic dispatch | Static dispatch only; call targets are always known at compile time |
| Anonymous tuples | Named structs only |

Anonymous lambdas with **immutable captures** are supported (`|x| x + 1`) — they power higher-order stdlib functions (`map`, `filter`, `fold`). Only *mutable* closures are banned.

Result: ~10 statement forms, ~5 expression forms, ~3 declaration forms.

**Instantiates:** #2 (removes multiple ways to express one concept), #3 (moves capabilities into the stdlib rather than the grammar).

### 8. LL(1) grammar, hand-written recursive descent

*(ADR-0005)*

Grammar fits in ~100 EBNF productions, LL(1), no lookahead beyond one token. Hand-written parser — no parser generator, no macros, no PEG.

Every ambiguity that could require lookahead beyond one token was eliminated by language design:

- Generic type arguments use `[T]` not `<T>` (because `name<` requires multi-token lookahead to distinguish comparison from generic application)
- `if` is always an expression, never only a statement
- `match` arms always end with `,`
- `pub` is factored out front so each declaration starts with a distinct keyword

**Instantiates:** #2 at the grammar level — LL(1) means every construct has one unambiguous parse.

### 9. Ownership, not GC

*(ADR-0029)*

Memory safety via linearity and reference capabilities (`val`, `ref`, `iso`, `tag`) adapted from Pony. No garbage collector, no tracing runtime. Deterministic deallocation, suitable for real-time and safety-critical use.

**Instantiates:** Req 6 in #6 (ownership is one of the eleven), #4 (lifetime is in the type, not hidden in a runtime).

---

## At a glance

| # | Principle                                    | Tier       | Anchor ADR |
|---|----------------------------------------------|------------|------------|
| 1 | Explicit over implicit                       | Meta       | 0017 / 0026 |
| 2 | One syntax per concept                       | Meta       | 0002 / 0004 |
| 3 | Vocabulary over syntax                       | Meta       | 0002       |
| 4 | The signature IS the threat model            | Meta       | 0001 / 0004 |
| 5 | Honest over silent                           | Meta       | 0024 / 0026 |
| 6 | Eleven requirements — no more, no less       | Structural | 0001       |
| 7 | Language contraction                         | Structural | 0002       |
| 8 | LL(1) grammar, hand-written recursive descent | Structural | 0005       |
| 9 | Ownership, not GC                            | Structural | 0029       |

## What's not on this list

The following are **outputs** of the principles above, not principles themselves. They are captured in specs and ADRs:

| Choice                          | Captured in                                 |
|---------------------------------|---------------------------------------------|
| Total by default                | Spec 013, Req 8                              |
| Immutable by default (`ref`)    | Spec 001, Req 6                              |
| Effects in signatures           | Spec 002, Req 7, ADR-0035                    |
| Security labels on all data     | Spec 003, Req 11, ADR-0017 / 0024 / 0036     |
| Refinement types inline         | Spec 018, Req 10, ADR-0025                   |
| Actors, not threads             | Spec 015, Req 9, ADR-0029 / 0037             |
| No bare `unwrap()`              | Stdlib policy, follows from #1               |
| The `ref` keyword, not `mut`    | Spec 001, follows from #1 and Req 6          |

If you find yourself proposing a new "principle" that is really one of these, capture it in the relevant spec/ADR instead. The principles page stays small on purpose.

---

## See Also

- [The 11 Requirements](../why/requirements.md) — detailed explanation of each requirement
- [Language Overview](overview.md) — syntax and structure
- [ADR index](https://github.com/mvl-lang/mvl/tree/main/.openspec/adr) — all architectural decisions
