---
hide:
  - navigation
  - toc
---

<div style="text-align: center; margin: 2em 0;">
  <img src="assets/lynx_small.png" alt="MVL Lynx" style="width: 240px; height: 180px;">
</div>

# MVL — Maximum Verifiable Language

> *Your AI writes code faster than you can review it. The compiler should prove all of it.*

The economics of verification have flipped.

For decades, formal methods lost to shipping speed. Annotations cost time. Developers minimized them. Teams shipped bugs because proving correctness cost more than fixing crashes.

LLMs changed the equation. An AI writes annotations as easily as any other line of code. Effect declarations, refinement predicates, ownership markers, information flow labels — the verbosity that made verification impractical is now free.

**MVL is built for this moment.** The compiler proves 11 properties before your code runs: no null pointers, no buffer overflows, no data races, no unhandled errors, no secret leaks. The LLM writes. The compiler proves. You ship with mathematical certainty.

---

## :material-download: Install in 10 seconds

```bash
curl -fsSL https://mvl-lang.org/install.sh | sh
```

## :material-rocket-launch: Hello, verified world

```mvl
fn main() -> Unit ! Console {
    println("Hello, world!");
}
```

```bash
cd examples && mvl run hello_world.mvl
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

fn main() -> Unit ! Console {
    let result: Int = double(5);   // compiler proves 5 > 0
    println(result.to_string())
}
```

Try breaking it:

```mvl
fn double(x: Int where x > 0) -> Int where self > 0 {
    x * 2
}

fn main() -> Unit ! Console {
    let result: Int = double(-1);  // compile error!
}
```

```
error[REQ10]: refinement predicate violated
 --> example.mvl:6:23
  |
6 |     let result: Int = double(-1);
  |                       ^^^^^^^^^^ argument to `double` violates refinement `self > 0`
```

The compiler **proves** it at compile time. No runtime check needed.

---

## :material-forum: Join the community

- :material-github: **GitHub Discussions** — announcements, Q&A, ideas: [github.com/mvl-lang/mvl/discussions](https://github.com/mvl-lang/mvl/discussions/categories/announcements)
- :simple-discord: **Discord** — real-time chat in: [Lab271#mvl](https://discord.gg/BuWfh7A2A)

Questions, feedback, or partnership inquiries? See the [contact page](community/contact.md).

---

## :material-open-source-initiative: Open source

MVL is Apache-2.0 licensed. Built by [LAB271](https://github.com/LAB271).

[Get Started](getting-started.md){ .md-button .md-button--primary }
[View on GitHub](https://github.com/mvl-lang/mvl-lang.github.io){ .md-button }
