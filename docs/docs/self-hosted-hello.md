# Self-Hosted Hello World

This page walks through the first end-to-end execution of a program compiled by the self-hosted MVL emitter: the Rust frontend parses and lowers `hello_world.mvl` to TIR, the MVL-in-MVL LLVM backend emits LLVM IR, and `llc` + `cc` produce a native binary that prints `Hello, world!`.

This is the tracer bullet for self-hosting Phase A (#1746).

---

## What Runs Where

```
hello_world.mvl
      │
      │  mvl tir                 ← Rust compiler: parse, check, lower to TIR JSON
      ▼
  tir.json  ─────────────────────────────────────────────────────────
      │                                                              │
      │  mvl run compiler/backends/llvm/emitter.mvl                 │
      │  ↑                                                           │
      │  MVL-in-MVL: the self-hosted LLVM emitter,                  │
      │  written in MVL, compiled by the Rust bootstrap              │
      ▼                                                              │
  hello.ll  (LLVM IR text)       ← this is the handoff point        │
      │                                                              │
      │  llc -filetype=obj                                           │
      ▼                                                              │
  hello.o                                                            │
      │                                                              │
      │  cc -o hello                                                 │
      ▼                                                              │
  ./hello  →  Hello, world!   ←──────────────────────────────────────
```

The key milestone: the binary `./hello` was produced without the Rust compiler ever touching `hello_world.mvl`'s semantics. The Rust frontend only lowered it to TIR. Everything after that — instruction selection, register allocation decisions, the actual LLVM IR — came from MVL code running MVL code.

---

## Prerequisites

Build the bootstrap compiler:

```bash
git clone https://github.com/mvl-lang/mvl.git
cd mvl
cargo build
export PATH="$PWD/target/debug:$PATH"
```

Install LLVM (provides `llc`):

```bash
# macOS
brew install llvm
export PATH="/opt/homebrew/opt/llvm/bin:$PATH"

# Linux (Debian/Ubuntu)
apt install llvm
```

---

## Running It

### The full pipeline in one command

```bash
make test-bootstrap-e2e
```

Expected output:

```
  Running hello_world.mvl through self-hosted LLVM emitter...
  ✓  hello_world: Hello, world!
```

### Step by step

**Step 1 — Rust frontend: MVL source → TIR JSON**

```bash
mvl tir examples/programs/hello_world.mvl
```

`mvl tir` parses, type-checks (all 11 requirements), lowers to Typed IR, and serialises the result as JSON to stdout. The JSON is the handoff format between the Rust frontend and the self-hosted backends.

Sample output (abbreviated):

```json
{
  "fns": [
    {
      "name": "main",
      "params": [],
      "return_ty": "Unit",
      "effects": ["Console"],
      "body": {
        "stmts": [
          { "kind": "Expr", "expr": { "kind": "Call", "name": "println",
              "args": [{ "kind": "Literal", "value": "Hello, world!" }] } }
        ]
      }
    }
  ]
}
```

**Step 2 — Self-hosted emitter: TIR JSON → LLVM IR**

```bash
mvl tir examples/programs/hello_world.mvl \
  | mvl run compiler/backends/llvm/emitter.mvl
```

`compiler/backends/llvm/emitter.mvl` is a MVL program, compiled on the fly by the Rust bootstrap (`mvl run`), that reads the TIR JSON on stdin and writes LLVM IR text to stdout.

Sample output:

```llvm
; MVL self-hosted LLVM emitter — generated
target triple = "arm64-apple-macosx15.0.0"

@.str.0 = private unnamed_addr constant [14 x i8] c"Hello, world!\00"

declare i32 @puts(i8*)

define i32 @main() {
entry:
  %0 = getelementptr inbounds [14 x i8], [14 x i8]* @.str.0, i32 0, i32 0
  call i32 @puts(i8* %0)
  ret i32 0
}
```

**Step 3 — `llc`: LLVM IR → object file**

```bash
llc -filetype=obj hello.ll -o hello.o
```

**Step 4 — `cc`: object → binary**

```bash
cc -o hello hello.o -lc
```

**Step 5 — Run it**

```bash
./hello
# Hello, world!
```

---

## The Source Program

```rust
// examples/programs/hello_world.mvl
// Simplest possible MVL program.
// Exercises: Console effect (Req 7).

fn main() -> Unit ! Console {
    println("Hello, world!");
}
```

Eight tokens of user code. The compiler verifies Requirement 7 (effect tracking) — `println` requires `! Console` in the signature, and the compiler confirms it is declared.

---

## The Self-Hosted Emitter

The emitter lives at `compiler/backends/llvm/`. It is written in MVL and verified by `mvl check compiler/` — the emitter itself satisfies all 11 requirements:

```
compiler/backends/llvm/emit_context.mvl  — string builder, target triple, data layout
compiler/backends/llvm/emit_types.mvl    — MVL types → LLVM types
compiler/backends/llvm/emit_helpers.mvl  — constants, globals, intrinsics
compiler/backends/llvm/emit_exprs.mvl    — expression emission
compiler/backends/llvm/emit_stmts.mvl    — statement emission
compiler/backends/llvm/emit_match.mvl    — match expression lowering
compiler/backends/llvm/emit_program.mvl  — top-level: functions, types, extern decls
compiler/backends/llvm/emitter.mvl       — entry point: reads TIR JSON, calls emit_program
```

To verify the emitter source:

```bash
mvl check compiler/backends/llvm/
mvl assurance compiler/backends/llvm/ --verbose
```

---

## What This Proves

This pipeline demonstrates three things working together for the first time:

1. **TIR serialisation is correct.** The Rust frontend's `mvl tir` produces JSON that the self-hosted emitter can consume without modification.

2. **The self-hosted emitter produces valid LLVM IR.** `llc` accepts it without errors. `cc` links it. The binary runs.

3. **The end-to-end result is correct.** `./hello` prints exactly `Hello, world!` — the asserted output in `make test-bootstrap-e2e`.

This is the regression guard for the bootstrap pipeline. Any change to the Rust frontend's TIR serialisation, or to the MVL emitter's code generation, that breaks this pipeline is caught immediately.

---

## Where This Fits in Self-Hosting

| Phase | Scope | Status |
|-------|-------|--------|
| 1 | Shared types (`compiler/tir.mvl`) | ✅ Done |
| 3 | Lexer + recursive descent parser | ✅ Done |
| A | **MVL-hosted LLVM emitter + hello world e2e** | ✅ Done ← this page |
| 2 | Resolver, monomorphizer, TIR lowering | 🔄 In progress |
| 4 | Type checker + solver | 🔄 In progress |
| 6 | Three-stage bootstrap verify | ⬜ Planned |

Phase A is the partial self-hosting milestone: the emitter is fully written in MVL and verified, even though the frontend (parser, checker, lowering) still runs in Rust. The next milestone is a self-hosted frontend consuming self-hosted TIR.

---

## See Also

- [Bootstrapping](bootstrapping.md) — full bootstrap plan and phase table
- [Assurance Report](assurance.md) — how `mvl assurance compiler/` works
- [Language Reference](reference.md) — TIR and the compilation pipeline
