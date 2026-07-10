---
hide:
  - navigation
  - toc
---

<div style="text-align: center; margin: 2em 0;">
  <img src="assets/logo.svg" alt="MVL Lynx" style="width: 200px; height: 200px;">
</div>

# MVL — Maximum Verifiable Language

> *If your AI writes code without hesitation and your compiler guards the gate — why prove anything less than everything?*

**MVL is a programming language where the compiler verifies 11 properties at compile time.** No null pointers. No buffer overflows. No data races. No unhandled errors. No secret leaks. If it compiles, it's correct.

---

## :material-download: Install in 10 seconds

```bash
curl -fsSL https://mvl-lang.org/install.sh | sh
```

## :material-rocket-launch: Hello, verified world

```mvl
fn main() ! Console {
    println("Hello, verified world!")
}
```

```bash
mvl run hello.mvl
```

The `! Console` declares that this function has a console side effect. MVL tracks all effects in function signatures — nothing is hidden.

---

## :material-shield-check: What the compiler proves

Every MVL program passes through **11 verification checks** before any code is emitted:

| # | What the compiler proves | What it prevents |
|---|--------------------------|------------------|
| 1 | Type safety (ADTs) | Impossible states |
| 2 | Memory safety | Use-after-free, buffer overflow |
| 3 | Exhaustive matching | Unhandled cases |
| 4 | Null elimination | Null pointer dereference |
| 5 | Error visibility | Silent error swallowing |
| 6 | Ownership (linearity) | Double-free, resource leaks |
| 7 | Effect tracking | Hidden side effects |
| 8 | Termination | Infinite loops in total functions |
| 9 | Data race freedom | Concurrent access on shared state |
| 10 | Refinement types | Out-of-range values |
| 11 | Information flow | Secret/tainted data leaks |

**Code that compiles is well-formed.** Tests handle validation — does it do the right thing?

---

## :material-security: Why MVL?

<div class="grid" markdown>

!!! danger "Cybersecurity"
    AI-speed attacks need compile-time defenses. MVL makes entire vulnerability classes — injection, secret leakage, buffer overflow, privilege escalation — **structurally impossible**. Code that an attacker would exploit doesn't compile.

!!! success "Safety"
    Mission-critical systems (avionics, industrial, automotive) require formal evidence. The MVL compiler generates that evidence automatically: every property proven at compile time is an **audit artifact**.

</div>

---

## :material-robot: Designed for AI generation

LLMs can generate code effortlessly. They have semantic understanding of intent, patterns, and contracts. So why are we still writing code optimized for *human* typing speed?

**MVL flips the equation.** Annotations that are too tedious for a human developer — effect declarations, refinement predicates, ownership markers, information flow labels — are trivial for an LLM to generate. The code is verbose and explicit. The LLM doesn't mind. And every annotation it adds is a property the compiler can now *prove*.

**The LLM handles the syntax. The compiler handles the proof.**

- **~10 statement forms.** ~5 expression forms. ~3 declaration forms.
- **No macros, no inheritance, no exceptions, no null.**
- **One way to do each thing.** Dropping features makes the language more powerful — every dropped ambiguity is a property the compiler can now verify.

---

## :material-test-tube: A taste of verification

```mvl
fn double(x: Int where x > 0) -> Int where self > 0 {
    x * 2
}

fn main() ! Console {
    let result: Int = double(5);   // compiler proves 5 > 0
    println(result.to_string())
}
```

Try breaking it:

```mvl
fn main() ! Console {
    let result: Int = double(-1);  // compile error!
}
```

```
error[REQ10]: refinement violated
  --> example.mvl:7:30
   |
7  |     let result: Int = double(-1);
   |                              ^^ value -1 does not satisfy `x > 0`
```

The compiler **proves** it at compile time. No runtime check needed.

---

## :material-open-source-initiative: Open source

MVL is Apache-2.0 licensed. Built by [LAB271](https://github.com/LAB271).

[Get Started](getting-started.md){ .md-button .md-button--primary }
[View on GitHub](https://github.com/mvl-lang/mvl-lang.github.io){ .md-button }
