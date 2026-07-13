# Languages that Inspired MVL

MVL is not a research language. It borrows heavily — from Rust's ownership model, from Erlang's actors, from Ada's certification discipline, from Eiffel's contracts, from decades of formal-methods theory. What makes MVL distinctive is the combination: **every borrowed feature exists because it is compile-time verifiable at LLM authorship cost.** Features that require deep human insight to annotate correctly were left behind, no matter how elegant. Features that a language model can produce reliably were included, no matter how verbose.

This page is the credits reel. Each entry names what MVL took and what it left behind.

---

## Foundations of Proving

Before there were programming languages, there was the logic that programming languages would eventually verify. These are the mathematical roots.

### Curry–Howard correspondence (1934 / 1969)

Types are propositions; programs are proofs. If a function `fn double(x: Int) -> Int` type-checks, it is a constructive proof that from every integer, an integer can be produced. MVL's eleven requirements are all instances of this idea: every property enforced by the type system is a proposition the compiler has proven about the code.

### Hoare logic (1969)

`{P} C {Q}` — if precondition `P` holds and command `C` executes, postcondition `Q` will hold. This is the formal parent of every `requires` / `ensures` clause. MVL's function contracts (ADR-0025) are Hoare triples with LLM-generated predicates and compiler-discharged proofs.

### Martin-Löf type theory (1972 / 1984)

Intuitionistic type theory made refinement types and dependent types mathematically respectable. MVL doesn't ship full dependent types (they resist decidable checking), but its refinement types — `Int where x > 0` — descend directly from this line.

### Linear logic (Girard, 1987)

Every resource used exactly once. This is the theoretical parent of Rust's borrow checker and MVL's ownership discipline (Requirement 6). Without linear logic, there is no principled reason to reject double-free or use-after-move.

### Design by Contract — Eiffel (Meyer, 1988)

Contracts as first-class program elements, not comments. Bertrand Meyer coined `require` / `ensure` / `invariant` — the exact keywords MVL uses (ADR-0025). Eiffel enforced contracts at runtime; MVL enforces them at compile time via the solver. The idiom, the vocabulary, and the culture ("the specification is part of the program") are Meyer's.

---

## Rust — the syntactic ancestor

If MVL is one language distilled from many, that language *looks* like Rust. Ownership as a discipline, exhaustive pattern matching, `Result[T, E]`, `Option[T]`, no null, no exceptions, no inheritance, immutability by default — all recognisably Rust. The syntax was deliberately kept close so that Rust developers recognise the shape immediately.

MVL diverges in four important directions:

- **No borrowing, no lifetimes.** MVL does not have Rust's borrow checker. There is no `&'a T`, no `&'a mut T`, no lifetime annotations, no zero-copy slice discipline. Aliasing is handled by Pony-style reference capabilities (`val` / `ref` / `iso`), which is a fundamentally different mechanism — see the [Pony](#pony-reference-capabilities) section below. This is a deliberate contraction: lifetime annotation is one of the few things LLMs consistently produce incorrectly, and its verification cost is high relative to what capabilities buy you at actor boundaries.
- **More verification.** Rust proves memory safety and type safety brilliantly. MVL adds effect tracking, termination, refinement types, information flow control, and structured concurrency — five additional properties Rust does not verify.
- **Less flexibility.** Rust's macro system, trait system, unsafe blocks, and lifetime system exist for expressiveness. MVL removes all of them. The LLM writes verbose explicit code instead.
- **One backend, one proof chain.** Rust ships one compiler (`rustc`). MVL emits Rust *and* LLVM IR, then differentially tests them against each other. The long-term destination is a formally verified LLVM path with `rustc` out of the trust chain (spec 012, Phase 5).

Cargo also shaped `mvl install`, `mvl.toml`, and the lock-file model. The SBOM tooling extends Cargo's dependency graph with cryptographic hashes and provenance.

---

## Erlang / OTP — actors and supervision

MVL's actor model comes almost verbatim from Erlang: one actor per behavior, no shared state, message passing over typed mailboxes, supervision trees for fault tolerance. `std.actors` mirrors OTP's `supervisor` and `gen_server` patterns. The philosophy "let it crash and restart" is Erlang's; the safety net (Requirement 9 — data race freedom, checked at compile time) is MVL's addition.

Where Erlang uses dynamic types and lets protocol errors surface at runtime, MVL types mailboxes statically. A message that doesn't match the actor's protocol is a compile error, not a runtime pattern-match failure. Session types (spec 016) extend this to multi-message protocol verification — the direction Erlang never took because dynamic typing was the whole point.

Erlang's SASL and `logger` also shaped `std.audit`: structured events, actor identity as a first-class field, append-only truth.

---

## Ada / SPARK — safety-critical discipline

Ada gave MVL the culture of **one construct per concept** (Principle 2). SPARK gave MVL the culture of **certification artifacts** — the idea that a compiler's job includes producing evidence, not just object code. `mvl assurance` outputs a machine-readable proof record because DO-178C and IEC 61508 demand it, and Ada/SPARK proved this is achievable in production avionics for 30+ years.

Ada also contributed the pattern `type Positive is Integer range 1..MAX` — the direct ancestor of MVL's refinement types (`Int where x > 0`, Requirement 10). SPARK 2014 removed Ada's dynamic dispatch and closed the last verification holes; MVL does the same by construction.

MISRA C (a C subset for automotive safety) contributed the philosophy of **language contraction**: fewer features means fewer places for bugs to hide. ADR-0002 is MISRA C's philosophy applied to a whole language rather than a coding standard.

---

## The ML family — OCaml, Haskell, Standard ML

Algebraic data types, exhaustive pattern matching, `Some`/`None`, and the discipline of immutability by default all come from ML. Rust inherited them; MVL inherited them through Rust with the same shape. Requirement 1 (type safety through ADTs) and Requirement 3 (totality via exhaustive match) are the ML contribution.

MVL deliberately does *not* inherit ML's type inference on `let` bindings. Every binding requires an explicit type annotation. The LLM writes the annotation; the compiler no longer has to guess. This turns type errors into local, actionable failures instead of remote propagations.

Haskell also contributed the culture of "if it compiles, it works" — MVL sharpens this to "if it compiles, it satisfies eleven proven properties."

---

## Effect systems — Koka, Frank, Eff

`! Console`, `! Net`, `! DB + Audit` — MVL's effect annotations come from Koka (Leijen, 2014). Koka showed that row-polymorphic effects can be tracked in signatures without breaking type inference. MVL adopts the surface syntax; the underlying algebra is deliberately simplified (no effect polymorphism, no handlers as first-class values) because the LLM doesn't need the flexibility and the compiler is faster without it.

Requirement 7 (effect tracking) is Koka's contribution. Every side effect visible in the signature; no ambient effects, no hidden I/O.

---

## Refinement types — Idris, Dafny, Liquid Haskell, F*

Refinement types were theoretically available for decades and practically ignored because the annotation burden was too high for human developers. Liquid Haskell (Vazou et al., 2014) proved it was possible to bolt refinements onto an existing language; F* proved it could unify with effects; Dafny proved SMT-backed contracts were practical for industrial verification.

MVL takes:

- **Liquid Haskell's syntax:** `x: Int where x > 0`
- **Dafny's contract style:** `requires`, `ensures`, `decreases`
- **Idris's totality-by-default:** every function is total unless declared `partial`
- **F*'s discipline:** effects, refinements, and contracts all in the signature

Requirement 10 (refinement types) and Requirement 8 (termination) are this family's contribution. What MVL adds is the LLM authorship model: the annotations are cheap to produce, so the practicality objection dissolves.

---

## Information Flow Control — Jif, FlowCaml, Paragon

Denning's lattice model of secure information flow (1976) sat unused for decades outside academic experiments because labeling every variable is intolerable for human developers. Jif (Java + information flow) and FlowCaml (OCaml + information flow) demonstrated the discipline works; nobody adopted it.

MVL adopts it as Requirement 11. `Secret[T]`, `Tainted[T]`, and user-defined labels form a lattice; the compiler tracks label flow through every expression; `declassify` and `sanitize` are the only ways to lower a label, and they are audited. This is Denning's model, LLM-annotated at zero human cost, compile-time-enforced.

---

## Elm — no exceptions, no nulls

Elm proved that a mainstream frontend language can ship with `Result`-only error handling and `Maybe`-only optional values, without a single runtime exception in production. Elm's "friendly compiler" ethos also shaped MVL's diagnostic style — every error message is expected to point at the source line, name the requirement violated, and propose a fix. Requirement 4 (null elimination) and Requirement 5 (error visibility) descend from ML but were popularized by Elm.

---

## Go — simplicity as a feature

Go's insistence on **one way to do each thing** — one loop keyword, one error convention, one goroutine primitive — directly inspired MVL Principle 2 ("one syntax per concept"). Go's built-in tooling (`go fmt`, `go test`, `go vet`) also shaped `mvl fmt`, `mvl test`, `mvl lint`, and the assumption that tooling ships with the language, not as a third-party ecosystem.

MVL parts company with Go on nulls (Go has `nil`; MVL has `Option`), errors (Go's `error` interface is dynamic; MVL's `Result[T, E]` is static), and generics style. But the culture of "less is more" is unambiguously Go's.

---

## Zig — explicit resources

Zig's insistence that every allocation, every I/O operation, and every control-flow path be visible in the source shaped MVL's Principle 1 ("explicit over implicit"). Zig has no hidden allocation, no exceptions, no operator overloading — the same list MVL contracts (ADR-0002). Zig also demonstrated that cross-compilation can be a first-class feature, which will matter when MVL reaches Phase 8 (WASM) and Phase 10 (embedded).

---

## Pony — reference capabilities

Pony (Clebsch, 2015) is the direct source of MVL's aliasing model — a role that many readers assume belongs to Rust. It does not. Rust uses **lifetimes** to prove that references do not outlive their referents; Pony uses **reference capabilities** to prove that aliases cannot race. These are different mechanisms solving different problems.

Pony assigns every reference one of six capabilities: `iso` (isolated — exactly one alias, mutable, sendable), `val` (immutable value — many aliases, no writes, sendable), `ref` (mutable — many aliases in the same actor), `box` (read-only view), `tag` (opaque identity only), `trn` (writable now, freezable to `val`). The compiler tracks capabilities through every expression and enforces sendability at actor boundaries: only `iso` and `val` may cross.

MVL adopts a **contracted** version — three capabilities where Pony has six:

| MVL capability | Meaning | Pony equivalent |
|----------------|---------|-----------------|
| `val` | immutable value; freely aliasable; sendable | `val` |
| `ref` | mutable within one actor; not sendable | `ref` |
| `iso` | uniquely-owned; mutable; sendable by transfer | `iso` |

`box`, `tag`, and `trn` are dropped because the additional annotation surface is not worth the flexibility once dynamic dispatch and inheritance are also gone. What remains is the essential property Pony pioneered: **compile-time data race freedom without a garbage collector and without a borrow checker.**

Requirement 9 (data race freedom) is Pony's contribution, combined with Erlang's actor model. MVL does not have Rust's ownership *system* — it has Rust's ownership *syntax* on top of Pony's capability *semantics*. This is not a distinction most language designers would make; MVL makes it deliberately because the LLM authors the annotations and the compiler needs the discipline that produces the tightest verification per annotation token.

---

## Proof assistants — Lean 4, Coq, Isabelle/HOL, Agda

The eleven requirements are proven at compile time by the MVL compiler. But nothing proves the MVL compiler itself. That gap closes in Phase 9, when the MVL type system will be formalized in Lean 4 (or Coq) and its soundness theorem discharged: every well-typed MVL program satisfies each of the eleven requirements.

Lean 4 is the current target because it combines general programming with proof — the compiler code and the proof can share definitions. Idris 2 also contributed the quantitative type theory that underlies MVL's linearity levels (`val`, `ref`, `iso`).

---

## Verified compilers — CompCert, seL4

The **proof-chain principle** — one compiler, one proof, not "two independent compilers that agree" — is CompCert's contribution. This is why MVL Phase 5 aims to remove `rustc` from the trust chain: two compilers that agree on output are not the same as one compiler proven correct. The seL4 microkernel demonstrated end-to-end proof of a real system (kernel source through binary), and its methodology shapes the eventual MVL bootstrap: Rust `mvl₀` → MVL `mvl₁` → MVL `mvl₂`, byte-identical, with the whole chain in scope for formal verification.

---

## Testing lineage — QuickCheck, Stryker, DO-178C MC/DC

MVL's testing story is deliberately conservative. Nothing new was invented; everything comes from established practice:

- **Property-based testing** — QuickCheck (Claessen & Hughes, 2000), Hypothesis (Python). Shape of `std.pbt`.
- **Mutation testing** — Stryker, mutmut, Pitest. `mvl mutate` emits mutants at the AST level (ADR-0014).
- **MC/DC coverage** — the DO-178C avionics standard's coverage metric. `mvl mcdc` (ADR-0015) makes it a first-class command, not a fourth-party plugin.

The combination — property-based generation + mutation-tested oracles + MC/DC branch coverage + all eleven compile-time checks — is what MVL calls the *five-layer test discipline*.

---

## Packaging lineage — Cargo, npm, SLSA, in-toto

Cargo contributed the manifest + lock-file + hash-verify model. npm contributed the lesson that untrusted dependencies are the primary attack surface (`event-stream`, `left-pad`, and every supply-chain incident since). SLSA (Supply-chain Levels for Software Artifacts) contributed the provenance-level ladder that `mvl audit` and `mvl sbom` climb.

`mvl.toml` is Cargo with three additions: an `extern` rationale field (every FFI boundary needs a written justification), a `capabilities` block (what effects the package's public API uses), and an `assurance` field (which requirements are proven for the package).

---

## What MVL deliberately does *not* inherit

Every language above contributed something. MVL also deliberately rejected features from every one of them:

| Rejected feature | Where it came from | Why rejected |
|------------------|---------------------|--------------|
| Macros | Rust, Lisp, C++ | Verification opacity — the compiler cannot reason about generated code |
| Traits with dynamic dispatch | Rust, Java, Go | Non-static call targets defeat effect and termination analysis |
| Type inference on bindings | ML, Haskell | Errors propagate; explicit annotations localize failures |
| Exceptions | Java, C#, C++, Python | Hidden control flow (violates Principle 1) |
| Null | C, Java, Go, Python | Requirement 4 rejects it |
| Operator overloading | C++, Scala, Rust | Surprise semantics — one meaning per operator |
| Inheritance | Java, C++, Python | Implicit method resolution order; composition suffices |
| Global mutable state | C, Java, Python | Every mutation must have an owner (Req 9) |
| Full dependent types | Idris, Coq, Agda | Undecidable checking; too high an annotation cost even for LLMs |
| Effect handlers as first-class values | Koka, Frank | Compiler complexity; row-polymorphic effects alone suffice |
| Unsafe blocks | Rust | The trust chain must be closed — no escape hatches |

Each rejection is deliberate. Every dropped feature is a property the compiler can now verify.

---

## The pattern

MVL is **Rust's core** + **Eiffel's contracts** + **Erlang's actors** + **Ada's certification discipline** + **Koka's effects** + **Liquid Haskell's refinements** + **Jif's information flow** + **modern supply-chain hygiene** — held together by one bet:

> The annotation burden that made effects, IFC, refinements, contracts, and totality impractical for humans is trivial for LLMs. Every borrowed feature exists because it is compile-time verifiable at LLM authorship cost. The languages that failed to reach mainstream adoption failed on annotation ergonomics, not on verification power. MVL removes the human from that equation.

---

## See Also

- [Design Principles](principles.md) — the meta-principles and structural decisions that these inspirations produced
- [The 11 Requirements](../why/requirements.md) — the specific properties each inspiration contributed
- [References (repo)](https://github.com/mvl-lang/mvl/blob/main/docs/references.md) — full bibliography with BibTeX
