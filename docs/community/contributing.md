# Contributing

MVL is an open-source project developed by [LAB271](https://github.com/mvl-lang). Contributions are welcome — code, tests, documentation, and bug reports.

---

## Before You Start

- Browse [open issues](https://github.com/mvl-lang/mvl/issues) to find something to work on, or open a new issue to discuss your idea first.
- For substantial changes (new language features, stdlib additions, architecture changes), open an issue or discussion before writing code. MVL has strong design constraints (ADR-0001 through ADR-0005); proposals that relax them will not be accepted.
- Check the [ADR index](https://github.com/mvl-lang/mvl/tree/main/.openspec/adr) — many design decisions are already settled. Understanding *why* the language is shaped the way it is saves significant back-and-forth.

---

## Development Setup

### Prerequisites

- **Rust** (stable, ≥ 1.86): `curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh`
- **Z3** (optional — required for Layer 5 solver tests): `brew install z3` / `apt install libz3-dev`
- **Node.js** (optional — required for tree-sitter grammar tests): `brew install node`

### Clone and Build

```bash
git clone https://github.com/mvl-lang/mvl.git
cd mvl
make setup    # install git hooks and verify toolchain
make build    # debug build → target/debug/mvl
make doctor   # verify all dev tools are present
```

### Running Tests

```bash
make test           # pre-PR gate: unit + type checker + corpus + solver (~1–2 min)
make test-full      # pre-merge gate: everything including stdlib, backends, examples (~10–20 min)
```

Key test targets:

| Target | What it runs |
|--------|-------------|
| `make test-corpus` | Parse + type-check all 300+ corpus examples |
| `make test-solver` | Refinement solver (Layers 1–5) |
| `make test-requirements` | One proven + one failing test per requirement |
| `make test-error-messages` | Exact diagnostic output matching |
| `make test-stdlib` | Standard library integration tests |
| `make test-mvl` | MVL-in-MVL compiler self-tests |
| `make test-backend-rust` | Rust transpiler backend |
| `make test-backend-llvm` | LLVM IR backend |

### Code Quality

```bash
make check          # lint, type-check, format check
make lint           # Clippy (Rust) + mvl lint (MVL)
make format         # auto-format Rust and MVL source
make assure-compiler  # assurance report for the self-hosted compiler
```

---

## Workflow

MVL uses a worktree-based parallel development workflow. Standard branch naming:

| Branch | Format | Triggers |
|--------|--------|---------|
| Feature | `feat/description` | Minor version bump |
| Bug fix | `fix/description` | Patch bump |
| Refactor | `refactor/description` | No bump |
| Documentation | `docs/description` | No bump |
| Chore | `chore/description` | No bump |

### Pull Request Checklist

Before opening a PR:

- [ ] `make test` passes locally
- [ ] `make check` passes (no lint warnings, no format drift)
- [ ] New code has tests — unit tests for Rust, corpus tests for new MVL syntax
- [ ] If you added an MVL syntax feature, add a corpus test in `tests/corpus/`
- [ ] If you changed the grammar, update `docs/grammar.ebnf` and run `make test-grammar-coverage`
- [ ] If you made an architectural decision, add or update an ADR in `.openspec/adr/`
- [ ] CHANGELOG.md has an entry under the unreleased section

### Corpus Tests

Corpus tests live in `tests/corpus/` organised by requirement category:

```
tests/corpus/
├── 01_syntax/         ← lexing and parsing
├── 02_functions/      ← function declarations and calls
├── 03_types/          ← struct, enum, type aliases
├── 07_effects/        ← effect declarations and propagation
├── 09_refinements/    ← where clauses and solver
├── 11_contracts/      ← requires / ensures
├── 12_actors/         ← actor declarations and messages
└── ...
```

Positive tests must parse and type-check. Negative tests (expected errors) are marked with a comment:

```mvl
// corpus:expect-fail REQ10 refinement violated
fn bad(x: Int where x > 0) -> Unit { bad(-1) }
```

---

## MVL Code Standards

When writing `.mvl` files (corpus tests, stdlib, examples):

- All `let` bindings require explicit types: `let x: Int = 42;`
- Mutable bindings use `ref`: `let count: ref Int = 0;`
- Generics use square brackets: `List[T]`, not `List<T>`
- No trailing semicolon on the return expression
- Match arms always end with `,` (including the last)
- Prefer `while true { ... return; }` over tail-recursive loops
- Mark pure, terminating functions `total`; mark potentially non-terminating functions `partial`
- Verify after writing: `cargo run -- check <file.mvl>`

---

## Adding to the Standard Library

Stdlib modules live in `std/`. Guidelines:

- Every exported function that can fail returns `Result[T, E]` — never panics
- Every function with side effects declares them with `!`
- Functions receiving external data must label their parameters `Tainted`
- New modules need tests in `tests/stdlib/`
- `pub builtin fn` declarations require a Rust implementation in `mvl_runtime/src/stdlib/`
- Run `make test-stdlib` to verify your additions

---

## Reporting Bugs

Open an issue at [github.com/mvl-lang/mvl/issues](https://github.com/mvl-lang/mvl/issues). Include:

- MVL version: `mvl --version`
- The `.mvl` file that triggers the bug (minimal reproduction)
- Expected behaviour and actual behaviour
- Whether it's a compiler crash, wrong error, wrong output, or missing diagnostic

For security issues, email **security@mvl-lang.org** instead of opening a public issue.

---

## Proposing Language Changes

MVL has a strong design invariant: features are added only if they increase the number of properties the compiler can verify, without increasing the annotation burden disproportionately (ADR-0002, ADR-0004).

Proposals that add syntax for writability, ergonomics, or familiarity without a verification payoff will not be accepted. This is not negotiable — the design constraints are the project.

For proposals that do clear the bar:

1. Open an issue describing the feature, the verification benefit, and the annotation cost
2. Link any relevant ADRs or formal references
3. Add a spike test in `tests/spikes/` to explore the implementation
4. If accepted, write the ADR before the implementation PR

---

## License

MVL is licensed under [Apache 2.0](https://github.com/mvl-lang/mvl/blob/main/LICENSE). By contributing, you agree that your contributions are licensed under the same terms.
