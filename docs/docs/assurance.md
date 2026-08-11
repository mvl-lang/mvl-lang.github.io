# Assurance Report

The `mvl assurance` command generates a machine-readable verification report that summarises how many of the eleven requirements are proven for each module, function, and type in your project.

---

## Running the Assurance Command

```bash
# Summary report for a file or directory
mvl assurance myproject/

# Verbose — per-function detail
mvl assurance myproject/ --verbose

# Machine-readable JSON (for CI, dashboards, compliance tools)
mvl assurance myproject/ --json

# Pass/fail gate (exits non-zero if any requirement is unproven)
mvl assurance myproject/ --gate
```

---

## Report Structure

### Summary View

```
MVL Assurance Report
====================
Files checked:       6 source files  (2 *_test.mvl excluded)
Functions:           42
  total fn:          14 (14 explicit, 0 implicit)
  partial fn:        28
  extern fn:         0 (0% trust boundary)
  implemented:       42
  test fn:           8
Totality coverage:   14/42 implemented fns are total

Requirements:
  Req  1  Type Safety             ✓  42 functions, 0 violations
  Req  2  Memory Safety           ✓  42 functions, 0 violations
  Req  3  Exhaustive Matching     ✓  18 match expressions, 0 non-exhaustive
  Req  4  Null Elimination        ✓  0 nullable types, 0 unhandled Option
  Req  5  Error Visibility        ✓  0 unhandled Result
  Req  6  Ownership               ✓  0 use-after-move, 0 double-free
  Req  7  Effect Tracking         ✓  28 effectful fns, 0 undeclared effects
  Req  8  Termination             ✓  14 total fn, 0 unbounded loops
  Req  9  Data Race Freedom       ✓  actor model; 0 shared mutable state
  Req 10  Refinement Types        ✓  6 refinement sites, 0 runtime (6 proven)
  Req 11  IFC Labels              ✓  0 label violations, 4 relabel sites audited

Struct types:          8 (5 refined fields, 0 with invariants)
Refinement proofs:
  proven:     6  (L1:4, L2:1, L3:0, L4:1, L5:0)
  runtime:    0
  failed:     0
```

### Verbose View

With `--verbose`, each function shows its totality, effects, capabilities, and per-requirement verdicts:

```
Name                    Kind     Totality  Effects          Caps   Refinements
────────────────────────────────────────────────────────────────────────────────
db_open                 fn       partial   DB+FileRead+FW   -      -
db_init                 fn       total     DB               val    -
row_to_user             fn       total     -                -      -
user_to_json            fn       total     -                val    0p/0r/1e
users_to_json           fn       total     -                -      0p/0r/1e
validate_port_range     fn       total     -                -      1p/0r/0e
```

Column meanings:
- **Totality** — `total` (proven), `partial` (may not terminate), `total*` (implicit)
- **Effects** — declared effect set
- **Caps** — capability annotations (`val`, `ref`, `iso`)
- **Refinements** — `Np/Nr/Ne` = N proven / N runtime / N ensures

### Refinement Proof Breakdown

```bash
mvl prove myproject/
```

```
myproject/handlers.mvl: refinement proof breakdown
  01:[46]  user_to_json  → user_to_json(result) — `ensures len(result) > 0`  (1:trivial)
  02:[62]  users_to_json → users_to_json(result) — `ensures len(result) > 0`  (1:trivial)
  Summary: 2 proven (L1:2 L2:0 L3:0 L4:0 L5:0), 0 runtime, 0 failed

myproject/main.mvl: refinement proof breakdown
  01:[88]  main → validate_port_range(p) — `self > 0 && self < 65536`  (1:trivial)
  Summary: 1 proven (L1:1 L2:0 L3:0 L4:0 L5:0), 0 runtime, 0 failed

Total: 3 proven (L1:3 L2:0 L3:0 L4:0 L5:0), 0 runtime, 0 failed
```

The solver layers are:

| Layer | Label | Technique |
|-------|-------|-----------|
| L1 | `trivial` | Literal evaluation, subsumption, tautologies, concat chains |
| L2 | `interval` | Interval arithmetic on integer bounds |
| L3 | `symbolic` | Symbolic path analysis |
| L4 | `cooper` | Presburger / Cooper quantifier elimination |
| L5 | `z3` | Z3 SMT solver (requires `brew install z3` / `apt install libz3-dev`) |

Runtime proofs are valid — the constraint is checked at runtime. Failed proofs are compile errors.

---

## Properties in Detail

### What Each Verdict Means

**Property 1 — Type Safety**
The checker verifies that every expression has a compatible type, every enum arm matches the variant, and every struct field is initialised with the correct type. A violation here means the code uses a type in a way it was not declared to support.

**Property 2 — Memory Safety**
The ownership checker verifies no value is used after being moved, no resource is freed twice, and every reference is backed by a live owner. Violations show the location where ownership was lost.

**Property 3 — Exhaustive Matching**
Every `match` expression covers all possible variants of the matched type. Adding a new enum variant causes compile errors at every match that does not handle it.

**Property 4 — Null Elimination**
There is no null in MVL. Every optional value is `Option[T]`. A `None` case that is not handled in a `match` is a compile error.

**Property 5 — Error Visibility**
Every function that can fail returns `Result[T, E]`. A `Result` that is not handled (not matched, not propagated with `?`) is a compile error.

**Property 6 — Ownership**
Every linear type (file handle, database connection, actor reference) is consumed exactly once. A value used after it was moved, or a resource that leaves scope without being closed, is a compile error.

**Property 7 — Effect Tracking**
A function that calls `println` must declare `! Console`. A function that reads a file must declare `! FileRead`. Undeclared effects are compile errors. Effects propagate upward through call chains automatically.

**Property 8 — Termination**
Functions marked `total` are proven to terminate. For recursive functions, the compiler verifies structural decreasing. For loops, a `decreases` clause provides the variant. A function that cannot be proven to terminate must be marked `partial`.

**Property 9 — Data Race Freedom**
All mutable state lives inside actor fields. State is only accessible via message sends — never via direct field access from outside the actor. The compiler verifies that `pub fn` parameters are sendable (value types, `val`, or `iso` capabilities).

**Property 10 — Refinement Types**
`where` predicates on types and parameters are verified by the layered solver at call sites and return points. The `mvl prove` command shows which layer discharged each proof and which fell back to runtime.

**Property 11 — Information Flow Control**
`Tainted[T]` values from external input cannot reach database queries, network calls, or logs without an explicit `relabel` expression. `Secret[T]` values cannot flow to any output effect without declassification. Every `relabel` site carries an audit tag recorded in the report.

---

## IFC Audit Trail

All `relabel` expressions are tracked by the assurance report:

```
IFC Audit Trail
===============
  [handlers.mvl:52]  trust    Tainted[String] → String    tag: "XSS-validated"
  [handlers.mvl:89]  classify String → Secret[String]     tag: "PII-001"
  [audit.mvl:34]     trust    Secret[String] → String     tag: "mask-for-logging"

  3 label transitions, 3 audit tags, 0 untagged relabels
```

This is the complete inventory of every point where a security boundary was crossed. Every `relabel` without an audit tag is a compile error.

---

## CI Integration

### Gate Check

```bash
# Exits 0 on full coverage, 1 on any unproven requirement
mvl assurance --gate myproject/

# In CI (GitHub Actions, etc.)
- name: Assurance gate
  run: mvl assurance --gate src/
```

### JSON Output

```bash
mvl assurance --json myproject/ > assurance.json
```

The JSON structure:

```json
{
  "schema": "mvl-assurance/1",
  "files": [
    {
      "path": "handlers.mvl",
      "requirements": {
        "1": { "verdict": "proven", "violations": [] },
        "10": {
          "verdict": "proven",
          "proofs": [
            { "line": 46, "fn": "user_to_json", "layer": 1, "predicate": "len(result) > 0" }
          ]
        }
      }
    }
  ],
  "summary": {
    "total_functions": 42,
    "total_proofs": 6,
    "runtime_proofs": 0,
    "failed_proofs": 0
  }
}
```

### SBOM Generation

```bash
mvl sbom --format cyclonedx --output sbom.json
mvl sbom --format spdx
```

Produces a complete software bill of materials including MVL dependencies, native Rust crates, and C libraries. PURL format: `pkg:mvl/<name>@<version>`.

### Supply Chain Audit

```bash
mvl audit --supply-chain   # hash integrity, extern rationale, known vulnerabilities
mvl audit --license        # SPDX license compatibility check
```

Configure allowed licenses in `mvl.toml`:

```toml
[policy]
allowed-licenses = ["MIT", "Apache-2.0", "BSD-2-Clause", "BSD-3-Clause"]
denied-licenses  = ["GPL-3.0", "AGPL-3.0"]
```

---

## The Evidence Chain

A complete `mvl build` produces:

```
Source Code
    ↓ mvl build
    ├── Binary                  (the executable)
    ├── assurance.json          (11-requirement proof record)
    ├── sbom.cyclonedx.json     (dependency inventory)
    ├── mvl.lock                (pinned versions + SHA-256 hashes)
    └── audit.log               (license + supply chain results)
```

This chain is the compliance artefact for DO-178C, IEC 61508, ISO 26262, SOC 2, and similar frameworks. The assurance report is machine-generated from the same compiler invocation that produced the binary — the proof record and the binary cannot diverge.

---

## See Also

- [Build Assurance](../why/build-assurance.md) — supply chain, SBOM, package manifest
- [The 11 Properties](../why/properties.md) — detailed explanation of each requirement
- [Language Reference](reference.md) — refinement types and the solver
