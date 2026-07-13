# The Proving Lineage

MVL's ability to prove eleven properties at compile time is not a single invention. It is a **cumulative inheritance** — sixty years of logic, type theory, contract programming, refinement types, and verified compilation folded into one language design. This page traces the chain of ideas that made compile-time verification of the eleven requirements practical.

Each row names an ancestor, what it contributed, and where that contribution lives in MVL today.

---

## The Chain

| Ancestor | Year | Contribution to MVL |
|----------|------|---------------------|
| **Curry–Howard correspondence** | 1934 / 1969 | Types = propositions, programs = proofs. The logical foundation for "types carry the proof." Every one of the eleven requirements is an instance of this idea. |
| **Hoare logic** | 1969 | Hoare triples `{P} C {Q}`. Formal parent of every `requires` / `ensures` clause. MVL's function contracts (ADR-0025) are Hoare triples with LLM-authored predicates. |
| **Martin-Löf type theory** | 1972 / 1984 | Intuitionistic type theory. Made dependent and refinement types mathematically respectable. Requirement 10 (refinement types) descends directly. |
| **Linear logic (Girard)** | 1987 | Every resource used exactly once. Theoretical parent of Rust's borrow checker and MVL's ownership discipline (Requirement 6). |
| **Design by Contract — Eiffel (Meyer)** | 1988 | `require` / `ensure` / `invariant` — the exact keywords MVL uses (ADR-0025). Eiffel enforced them at runtime; MVL enforces them at compile time via the solver. |
| **Ada / SPARK** | 1983 / 2014 | Contracts as certifiable evidence, not documentation. Refinement subtypes (`type Positive is Integer range 1..MAX`). 30 years of DO-178C track record. Shapes MVL's `mvl assurance` output. |
| **Dafny (MSR)** | 2008 | Contracts + SMT-backed static verification — the "no proof scripts" ergonomic. Compiler discharges obligations; developer writes only the specification. MVL's solver architecture (ADR-0025) follows this model. |
| **Liquid Haskell** | 2014 | Practical refinement types bolted onto an existing language. Proved that refinement checking can be automated by SMT for a restricted fragment. Requirement 10's design owes it the surface syntax. |
| **F\*** | 2011 | Contracts + refinements + effects unified in signatures. Demonstrated that the three disciplines compose without exploding proof obligations. MVL's signature model is F\*'s shape, contracted. |
| **Idris 2** | 2021 | Total-by-default (Requirement 8). Quantitative type theory — the levels behind MVL's `val` / `ref` / `iso` linearity discipline. |
| **Lean 4 / Coq** | 2013 / 1989 | Metatheory target for Phase 9. MVL's compiler is currently trusted; the plan is to formalize the type system in Lean 4 and discharge a soundness theorem: every well-typed MVL program satisfies each of the eleven requirements. |
| **CompCert / seL4** | 2006 / 2009 | The proof-chain principle — one compiler, one proof, not "two independent compilers that agree." Motivates MVL Phase 5 (drop `rustc` from the trust chain) and the future formally verified LLVM path. |

---

## The Three Layers

The lineage is not linear — it moves through three distinct layers, each building on the last.

### Layer 1 — Logical foundations (1934–1987)

Curry, Howard, Hoare, Martin-Löf, and Girard supplied the **mathematics**. They asked: what can be proven about a program, in principle, given a rich enough type system? The answer was: essentially everything, if the types are rich enough. But writing those types was intractable for humans.

MVL does not extend this layer. It stands on it.

### Layer 2 — Practical contract systems (1988–2014)

Meyer, Ada/SPARK, Dafny, Liquid Haskell, and F\* asked the next question: **how do we make this usable?** The answer was:

- Fix the syntax (`require` / `ensure` from Eiffel).
- Add SMT solvers so the developer doesn't write proofs by hand (Dafny).
- Restrict the logic to a decidable fragment (Liquid Haskell).
- Unify contracts, refinements, and effects into the type signature (F\*).

MVL is the direct heir of this layer. Its contract syntax is Eiffel's; its solver architecture is Dafny's; its refinement fragment is Liquid Haskell's; its signature-as-threat-model is F\*'s.

### Layer 3 — Verified compilation (2006–present)

CompCert and seL4 asked the final question: **what verifies the verifier?** If the compiler proves properties of programs, and the compiler itself is not proven, the trust chain terminates at a Rust codebase and an LLVM codebase, neither of which is formalized.

CompCert answered: formalize the compiler in Coq, prove semantic preservation. seL4 answered: formalize kernel and prove full functional correctness. MVL Phase 9 will follow: formalize the MVL type system in Lean 4, prove soundness of each of the eleven requirements, and verify the bootstrap chain.

---

## What Made It Practical

Every entry in the table above was theoretically available before MVL. Effect systems, refinement types, information flow control, and totality checking existed as research languages that never reached production. The blockers were the same in every case:

1. **Annotation burden** — every function needs types, effects, refinements, contracts, and labels.
2. **Ergonomic friction** — verbose signatures resist casual reading.
3. **Cost-benefit imbalance** — the developer effort to annotate outweighs the bug reduction.

LLMs invert all three. Annotation is trivial for an LLM. Verbose signatures are readable when the reader is a machine. And the cost of annotation approaches zero as generation approaches free. MVL is the language that assumes this inversion and pays the collected debt of sixty years of proving research.

The insight is not new. The context that makes it exploitable is.

---

## What MVL Does Not Inherit

The proving lineage also includes ideas MVL deliberately rejected.

- **Full dependent types** (Idris, Coq, Agda). Undecidable checking; too high an annotation cost even for LLMs. MVL restricts to decidable refinements.
- **Interactive proof assistants** (Coq, Lean, Isabelle tactics). No proof scripts in MVL source. If the compiler can't discharge it automatically, it falls back to runtime check or rejection.
- **Effect handlers as first-class values** (Koka, Frank, Eff). Compiler complexity; row-polymorphic effects alone suffice.
- **Proof-carrying code delivery** (Necula). The compiler emits binaries, not machine-checkable proofs. The assurance report is a summary, not a proof term.

Each rejection is a deliberate contraction — the same principle that made ADR-0002 possible at the language level, applied at the verification level.

---

## The Missing Piece

The current MVL compiler enforces the eleven requirements. Nothing formally verifies that the compiler is correct in doing so. This is the honest gap.

Phase 9 closes it. Lean 4 will hold the metatheory; the soundness theorem will state that every program accepted by `mvl check` satisfies each of the eleven requirements. Until that theorem is discharged, MVL trusts its own implementation the way every other production language does — with tests, review, and reproducible bootstrap.

The proving lineage will only be complete when the last link — the compiler itself — is proven.

---

## See Also

- [Design Principles](principles.md) — how the proving lineage shaped MVL's structural decisions
- [Languages that Inspired MVL](inspirations.md) — full inspiration list beyond the proving line
- [The 11 Requirements](../why/requirements.md) — the specific properties each ancestor contributed to
- [References (repo)](https://github.com/mvl-lang/mvl/blob/main/docs/references.md) — full bibliography
