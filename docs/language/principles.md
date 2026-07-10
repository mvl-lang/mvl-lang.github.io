# Design Principles

MVL is built on a small number of explicit decisions. Each one is documented in an Architectural Decision Record (ADR) in the repository. This page summarises the most foundational ones.

---

## 1. Eleven requirements — no more, no less

*(ADR-0001)*

The eleven requirements are not arbitrary. Each one was chosen because:

1. It catches a class of bugs that no combination of the other ten catches.
2. It can be verified at compile time with acceptable annotation cost.
3. It does not overlap with another requirement.

A twelfth requirement was considered (formal deadlock freedom for actors). It failed criterion 2: the annotation burden in practice is too high relative to the benefit. The eleven that remain each clear all three bars.

The requirements are split into two groups:

**Classical (1–6):** Rooted in 40 years of formal methods and safety-critical practice (MISRA C, DO-178C, IEC 61508, SPARK Ada). These became mainstream through Rust. MVL inherits them.

**Modern (7–11):** Effect tracking, termination, data race freedom, refinement types, and information flow control were all theoretically available before MVL. They were impractical because the annotation burden fell on human developers. With LLMs writing the code, the burden evaporates — the LLM writes the annotations, the compiler verifies them. MVL is the first language designed assuming LLM authorship as the normal case.

---

## 2. Language contraction

*(ADR-0002)*

MVL was built by subtraction. Every feature that exists for writability rather than verifiability was removed.

**Features deliberately excluded:**

| Feature | Why removed |
|---------|-------------|
| Mutable closures | Prevent capturing `ref` variables; eliminates a class of aliasing bugs |
| Implicit conversions | Every type boundary is explicit |
| Operator overloading | One meaning per operator; no surprise semantics |
| Default arguments | All parameters are explicit; no hidden state |
| Variadic arguments | Static arities only; prevents unverifiable call sites |
| Macros | No code generation outside the compiler; the compiler IS the macro system |
| String interpolation | Use `.concat()` — explicit and verifiable |
| Exceptions | `Result[T, E]` only — errors are values, never invisible |
| Null | `Option[T]` only — the "billion dollar mistake" is a compile error |
| `break` / `continue` | Loop control flow is explicit via `return` and `while true` |
| Inheritance | Composition only; no implicit method resolution order |
| Dynamic dispatch | Static dispatch only; call targets are always known at compile time |
| Global mutable state | All state lives in actor fields or explicit `ref` bindings |
| Anonymous tuples | Named structs only — no `(Int, String)` type syntax |

The resulting language is verbose and heavily annotated. That is intentional. LLMs write it, the compiler verifies it. A human reading the code gets maximum information from the signature alone.

---

## 3. Five-phase compilation

*(ADR-0003)*

MVL reaches a fully verified binary in five phases:

```
Phase 1 ✅  MVL → Rust transpilation           (bootstrap; real programs run now)
Phase 2 ✅  Rust FFI ecosystem integration      (extern blocks; native packages)
Phase 3 ✅  All 11 requirements enforced        (the language is now MVL)
Phase 4 ✅  Full stdlib in pure MVL             (no Rust in std/ except builtins)
Phase 5 🔄  Direct LLVM IR backend             (no rustc in the trust chain)
```

The Rust backend (Phase 1–4) is production-ready. The LLVM backend (Phase 5) eliminates `rustc` from the trust chain — the CompCert principle: one compiler, one proof chain. Two compilers that agree on output is not the same as one compiler that is correct.

---

## 4. The signature is the threat model

*(ADR-0001, ADR-0004)*

A function signature in MVL is a complete security contract:

```mvl
pub partial fn transfer(
    from: Secret[String],        // IFC: secret account ID
    amount: Int where self > 0,  // Refinement: must be positive
    val db: SqliteDb,            // Ownership: borrowed, not consumed
) -> Result[Unit, TransferError] ! DB + Audit  // Effects: database + audit trail
```

Reading the signature tells you:

- What data is sensitive (`Secret[String]`)
- What values are valid (`where self > 0`)
- What I/O this function does (`! DB + Audit`)
- What can go wrong (`Result[Unit, TransferError]`)
- Whether it terminates (`partial` — may not)

This is not optional documentation. The compiler enforces every claim. A function that logs a `Secret` value without declassification is a compile error, not a code review finding.

---

## 5. One syntax per concept

*(ADR-0002, ADR-0005)*

Every concept in MVL has exactly one way to express it:

| Concept | The one way |
|---------|------------|
| Fallible computation | `Result[T, E]` with `?` propagation |
| Optional value | `Option[T]` with `Some(v)` / `None` |
| Mutable binding | `let x: ref T = ...` |
| Side effect | `! EffectName` in signature |
| Error handling | `match` or `?` — never `try/catch` |
| Iteration | `for x in collection` (total) or `while condition` (partial) |
| Generics | `fn name[T](...)` with square brackets |
| Loop invariant | `invariant predicate` inside `while` |

When there is one way to do something, the compiler can reason about it. When there are three ways, the compiler must handle all three and developers must learn all three. MVL chooses the former.

---

## 6. LL(1) grammar by design

*(ADR-0005)*

The parser is a hand-written recursive descent parser with a strictly LL(1) grammar. Every ambiguity that could require lookahead beyond one token was eliminated by language design:

- Generic type arguments use `[T]` not `<T>` (because `name<` requires multi-token lookahead to distinguish comparison from generic application)
- `if` is always an expression, never only a statement
- `match` arms always end with `,`
- `pub` is factored out front so each declaration starts with a distinct keyword

The LL(1) grammar fits in ≈100 productions. A developer can hold the entire grammar in working memory. The compiler is ~76 K lines of Rust — small enough to audit, and in the process of being ported to MVL so the compiler verifies itself.

---

## 7. No bare unwrap

A consequence of Requirements 4 and 5: there is no `.unwrap()` method on `Option` or `Result`. Extracting a value from a container always requires explicit handling:

```mvl
// CORRECT — be explicit about the missing case
let val: Int = match opt {
    Some(v) => v,
    None    => 0,
};

// CORRECT — propagate the error
let val: Int = opt.unwrap_or(0);

// WRONG — does not compile; unwrap() does not exist
let val: Int = opt.unwrap();
```

The absence of `unwrap()` is not a convenience removal. It closes the escape hatch that makes Requirements 4 and 5 optional in practice.

---

## 8. The `ref` keyword, not `mut`

Mutable bindings in MVL use `ref`, not `mut`:

```mvl
let x: Int = 42;        // immutable
let y: ref Int = 0;     // mutable — can be reassigned
y = y + 1;
```

`ref` is deliberate vocabulary: it signals that this binding participates in the ownership and aliasing analysis (Requirement 2 and 6). `mut` in Rust carries the same semantic weight but appears at the wrong grammatical position (`let mut x`) and is inconsistently applied to function parameters. MVL uses `ref` at the type level consistently.

---

## See Also

- [The 11 Requirements](../why/requirements.md) — detailed explanation of each requirement
- [Language Overview](overview.md) — syntax and structure
- [ADR index](https://github.com/mvl-lang/mvl/tree/main/.openspec/adr) — all architectural decisions
