# Getting Started

## Your First MVL Program

Create `hello.mvl`:

```mvl
fn main() ! Console {
    println("Hello, verified world!")
}
```

Run it:

```bash
mvl run hello.mvl
# Hello, verified world!
```

The `! Console` declares that this function has a console side effect. MVL tracks all effects in function signatures — nothing is hidden.

## Your First Verification

Create `positive.mvl`:

```mvl
fn double(x: Int where x > 0) -> Int where self > 0 {
    x * 2
}

fn main() ! Console {
    let result: Int = double(5);
    println(result.to_string())
}
```

Check it:

```bash
mvl check positive.mvl
# ✓ All 11 requirements verified
```

The compiler **proves** at compile time that:

- `double(5)` satisfies `x > 0` (refinement type)
- The return value satisfies `self > 0` (return refinement)
- `result` is always positive — no runtime check needed

Try breaking it:

```mvl
fn main() ! Console {
    let result: Int = double(-1);  // ← compile error!
}
```

```
error[REQ10]: refinement violated
  --> positive.mvl:7:30
   |
7  |     let result: Int = double(-1);
   |                              ^^ value -1 does not satisfy `x > 0`
```

## Assurance Report

```bash
mvl assurance positive.mvl --verbose
```

This generates a verification report showing which requirements were proven, how many proofs were discharged, and the evidence trail. Useful for compliance (DO-178C, IEC 61508, ISO 26262).

## Next Steps

- [The 11 Requirements](language/requirements.md) — what the compiler proves
- [Design Principles](language/principles.md) — why MVL is built this way
- [Examples](language/examples.md) — real programs with verification
