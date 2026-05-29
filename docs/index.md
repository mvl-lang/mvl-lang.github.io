---
hide:
  - navigation
---

# MVL — Maximum Verifiable Language

<div style="text-align: center; margin: 2em 0;">
<p style="font-size: 1.4em; color: #666;">What if your compiler proved your code correct — before running it?</p>
</div>

**MVL is a programming language where the compiler verifies 11 properties at compile time.** No null pointers. No buffer overflows. No data races. No unhandled errors. No secret leaks. If it compiles, it's correct.

<div class="grid cards" markdown>

-   :material-shield-check:{ .lg .middle } **11 Compile-Time Guarantees**

    ---

    Type safety, memory safety, null elimination, error handling, ownership, effects, termination, data races, refinement types, information flow — all proven before a single line runs.

    [:octicons-arrow-right-24: The 11 Requirements](language/requirements.md)

-   :material-robot:{ .lg .middle } **Designed for AI Generation**

    ---

    MVL is not designed for humans to write — it's designed for LLMs to generate and compilers to verify. Verbose, explicit, zero ambiguity. The LLM handles the syntax; the compiler handles the proof.

    [:octicons-arrow-right-24: Design Principles](language/principles.md)

-   :material-download:{ .lg .middle } **Install in 10 Seconds**

    ---

    ```bash
    curl -fsSL https://mvl-lang.org/install.sh | sh
    ```

    [:octicons-arrow-right-24: Installation Guide](install.md)

-   :material-rocket-launch:{ .lg .middle } **Hello, Verified World**

    ---

    ```mvl
    fn main() ! Console {
        println("Hello, verified world!")
    }
    ```

    [:octicons-arrow-right-24: Getting Started](getting-started.md)

</div>

## Why MVL?

Two forces converge:

- **Cybersecurity.** AI-speed attacks need compile-time defenses. MVL makes entire vulnerability classes — injection, secret leakage, buffer overflow, privilege escalation — structurally impossible.

- **Safety.** Mission-critical systems (avionics, industrial, automotive) require formal evidence. MVL generates that evidence automatically at compile time.

## The Compiler Proves It

Every MVL program passes through 11 verification checks before any code is emitted:

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

## Open Source

MVL is Apache-2.0 licensed. Built by [LAB271](https://github.com/LAB271).

[Get Started](getting-started.md){ .md-button .md-button--primary }
[View on GitHub](https://github.com/mvl-lang/mvl-lang.github.io){ .md-button }
