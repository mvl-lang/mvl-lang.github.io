# Language Reference

Complete reference for MVL syntax and type system. The grammar is LL(1) with ≈100 productions — see [`docs/grammar.ebnf`](https://github.com/mvl-lang/mvl/blob/main/docs/grammar.ebnf) in the repository for the formal specification.

---

## Program Structure

A `.mvl` file is a module. One file = one module. The module name is the filename without the extension.

```
program = { use_decl } { declaration }
```

### Imports

```mvl
use std.io.{read_file, write_file}
use std.log.{Logger, log_info}
use models                          // import whole module
use pkg.http.{Request, Response}    // package import
```

Dot-separated paths. `::` is accepted but `.` is preferred. Braced lists import multiple names.

### Declarations

```mvl
pub type   Name = ...         // type declaration (public or private)
pub fn     name(...) -> T     // function declaration
    total fn / partial fn     // with explicit totality
pub actor  Name { ... }       // actor declaration
pub effect Name > Effect      // effect declaration
pub label  Name;              // IFC label declaration
pub relabel name: A -> B;     // IFC transition declaration
extern "rust" { ... }         // foreign function declaration
```

`pub` makes a declaration visible outside the module.

---

## Types

### Primitive Types

| Type | Description | Example |
|------|-------------|---------|
| `Int` | 64-bit signed integer | `42`, `-7` |
| `Int8` … `Int64` | Fixed-width signed integers | `Int32` |
| `UInt8` … `UInt64` | Fixed-width unsigned integers | `UInt8` |
| `Float` | 64-bit floating point | `3.14` |
| `Float32`, `Float64` | Explicit-width floats | `1.0f32` |
| `Bool` | Boolean | `true`, `false` |
| `Char` | Unicode scalar value | `'a'`, `'\n'` |
| `Byte` | Unsigned 8-bit integer | `0u8` |
| `String` | UTF-8 string | `"hello"` |
| `Unit` | The empty type (one value: `()`) | `()` |

### Collection Types

| Type | Description |
|------|-------------|
| `List[T]` | Growable sequence |
| `Array[T, N]` | Fixed-size array (const-generic size) |
| `Map[K, V]` | Hash map |
| `Set[T]` | Hash set |

### Composite Types

```mvl
// Option — Some(v) or None
Option[T]

// Result — Ok(v) or Err(e)
Result[T, E]

// Struct
type Point = struct { x: Float, y: Float }

// Enum
type Color = enum { Red, Green, Blue, Rgb { r: UInt8, g: UInt8, b: UInt8 } }

// Type alias with optional refinement
type Port = Int where self > 0 && self < 65536
```

### Refinement Types

A `where` clause attaches a solver-discharged predicate to a type:

```mvl
type PositiveInt = Int where self > 0
type NonEmpty    = String where len(self) > 0

// On struct fields
type Person = struct {
    name:  String where len(self) > 0,
    age:   Int    where self >= 0,
}

// Cross-field invariant
type Range = struct {
    lo: Int,
    hi: Int,
} with invariant self.lo <= self.hi

// On parameters
fn sqrt(x: Float where self >= 0.0) -> Float { ... }
```

!!! note
    `where` in MVL always means a solver-discharged predicate. It never means a trait bound. MVL has no trait system.

### IFC Label Types

```mvl
Public[T]   // default; no label
Tainted[T]  // from untrusted external input
Secret[T]   // high-confidentiality data
```

Labels flow: `Tainted[String]` cannot be passed where `String` is expected without a `relabel` expression. Crossing a label boundary always requires an explicit audit tag.

### Capability Types

```mvl
val T   // borrowed, immutable (default for function parameters)
ref T   // mutable reference
iso T   // isolated — unique ownership, sendable to actors
```

### Function Types

```mvl
fn(Int, Int) -> Int
fn(String) -> Unit ! Console
fn(T) -> Option[T]
```

---

## Functions

```mvl
[totality] fn name[TypeParams](params) -> ReturnType [! Effects] [contracts] { body }
```

### Totality

| Keyword | Meaning |
|---------|---------|
| `total` | Compiler proves termination |
| `partial` | May not terminate |
| *(omitted)* | Inferred: `total` if provable, else `partial` |

### Parameters

```mvl
fn f(
    x: Int,                       // immutable value
    s: String where len(s) > 0,   // with inline refinement
    val db: SqliteDb,             // borrowed, not consumed
    iso buf: Buffer,              // isolated — caller gives up ownership
) -> Unit
```

### Return Type with Refinement

```mvl
fn parse_port(s: String) -> Int where self > 0 && self < 65536
```

### Effects

```mvl
fn name() -> T ! EffectA + EffectB + EffectC
```

### Contracts

```mvl
fn divide(a: Float, b: Float) -> Float
    requires b != 0.0
    ensures result * b == a
{
    a / b
}
```

`requires` — precondition (checked at call sites). `ensures` — postcondition (checked at return points). Both use the refinement predicate language.

### Extension Methods

```mvl
pub fn String::len(self) -> Int { ... }
pub fn List[T]::is_empty(self) -> Bool { self.len() == 0 }
```

Called with dot syntax: `"hello".len()`, `xs.is_empty()`.

---

## Statements

```mvl
let x: T = expr;           // immutable binding (type required)
let x: ref T = expr;       // mutable binding
x = expr;                  // assignment (only valid for ref bindings)
expr;                       // expression statement
return expr;                // early return
return;                     // return Unit
```

The last expression in a block is the implicit return value — no semicolon:

```mvl
fn double(n: Int) -> Int {
    let x: Int = n * 2;    // statement — semicolon
    x                       // return expression — no semicolon
}
```

### Control Flow

```mvl
// if — expression or statement
let label: String = if score > 90 { "A" } else { "B" };

// match — always exhaustive
match result {
    Ok(v)  => process(v),
    Err(e) => log_error(e),
}

// for — bounded iteration (contributes to total proof)
for item in collection { process(item) }

// while — unbounded (marks function partial)
while condition {
    step();
}

// while with loop variant (allows total proof)
while i < n decreases n - i {
    i = i + 1;
}

// while true + return (preferred for server loops)
while true {
    match accept() {
        Ok(conn) => handle(conn),
        Err(_)   => return,
    }
}
```

---

## Expressions

```mvl
// Literals
42        -7        3.14      true      false      'a'      "hello"

// Arithmetic (no operator overloading)
a + b     a - b     a * b     a / b     a % b

// Comparison
a == b    a != b    a < b     a > b     a <= b    a >= b

// Logic
a && b    a || b    !a

// Result / Option propagation
expr?     // returns Err/None if expression is Err/None; unwraps otherwise

// Function call
f(a, b)

// Method call
expr.method(args)

// Field access
expr.field

// Struct construction
Point { x: 1.0, y: 2.0 }

// List / Map literal
[1, 2, 3]
{"key": value, "other": value2}

// Lambda (immutable captures only)
|x: Int, y: Int| x + y

// Relabel (IFC boundary crossing)
relabel trust(secret_val, "audit-tag")
relabel sanitize(tainted_val, "validation-reason")
```

---

## Actors

```mvl
actor Name {
    field: Type
    field: Type = default_value

    // Async behavior — sendable parameters only (val / iso / value types)
    pub fn behavior_name(val arg: Type) -> ReturnType ! Effects { body }

    // Private sync helper — no sendability restriction
    fn helper_name(args) -> T { body }
}

// Spawn and use
let a: ActorName = spawn ActorName { field: value };
a.behavior_name(arg);   // message send — async
```

---

## Effects System

### Built-in Effects

| Effect | Covers |
|--------|--------|
| `Console` | `stdin`, `stdout`, `stderr` |
| `FileRead` | Reading files and directories |
| `FileWrite` | Writing, creating, deleting files |
| `Net` | TCP/UDP connections, DNS |
| `DB` | Database queries |
| `Log` | Structured logging |
| `Audit` | Compliance audit trail |
| `Trace` | Distributed tracing |
| `Env` | Process environment |
| `Clock` | System time |
| `Random` | Random number generation |
| `Spawn` | Actor creation |
| `Metric` | Metrics and counters |

### Effect Declarations

```mvl
effect Clock                    // base effect
effect Log > Clock              // Log subsumes Clock
effect IO > Console + FileRead  // composite effect
```

A function declaring `! IO` implicitly declares `! Console + FileRead`.

### Parameterised Effects (path / host scoping)

```mvl
fn read_config() -> Config ! FileRead("/etc/app/")
fn call_api()   -> Response ! Net("api.example.com")
fn read_only()  -> List[Row] ! DB("SELECT")
```

---

## IFC Labels

```mvl
// Label declarations
label Secret;
label Tainted;

// Transition declarations
relabel trust:    Tainted -> _ audit;   // audit = every call site is logged
relabel sanitize: Tainted -> _;

// In expressions
let clean:  String       = relabel sanitize(raw_input, "html-escape");
let secret: Secret[String] = relabel classify(value, "PII-001");
```

---

## Refinement Predicate Language

Used in `where` clauses, `requires`, and `ensures`:

```
pred = expr op expr
     | pred && pred | pred || pred | !pred
     | (pred)

expr = self | result | ident | integer | float
     | expr + expr | expr - expr | expr * expr | expr / expr | expr % expr
     | len(ident)        // string / list length
     | ident.field       // struct field access
```

The solver runs five layers in order, escalating only when needed:

| Layer | Technique | Coverage |
|-------|-----------|---------|
| 1 | Trivial patterns (literal args, subsumption, tautologies, concat chains) | ~40% |
| 2 | Interval arithmetic | ~20% |
| 3 | Symbolic path analysis | ~15% |
| 4 | Cooper / Presburger arithmetic | ~5% |
| 5 | Z3 SMT (feature-gated) | remainder |

Unproved predicates become runtime checks, visible in `mvl prove`.

---

## Extern Blocks

```mvl
extern "rust" {
    fn random_bytes(n: Int) -> List[Byte] ! Random;
    fn sha256(data: List[Byte]) -> List[Byte];
}

extern "c" {
    fn strlen(s: String) -> UInt64;
}
```

Every `extern` block requires an `extern-rationale` in `mvl.toml`.

---

## Modules

```mvl
// foo.mvl — module "foo"
// foo/bar.mvl — module "foo.bar"

use foo.{helper, util}
use foo.bar.{Thing}
use std.io.{read_file}
use pkg.http.{Request}
```

One file = one module. Directories group modules. No `mod` declarations — the filesystem is the module tree.

---

## See Also

- [`docs/grammar.ebnf`](https://github.com/mvl-lang/mvl/blob/main/docs/grammar.ebnf) — formal EBNF grammar
- [Standard Library](stdlib.md) — available modules and functions
- [Design Principles](../language/principles.md) — why the language is shaped this way
