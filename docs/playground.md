# The Playground

**[play.mvl-lang.org](https://play.mvl-lang.org)** — write MVL, compile it, run it, and
watch the compiler prove things about it. No install, no signup.

The playground exists because MVL's central claim is hard to believe from a
README. MVL is an assurance compiler: the argument is that *"the plane flies or
it doesn't"* is a compile-time property, not a slogan. That is much easier to
accept once you have watched a proof obligation fail on code you wrote yourself.

[Open the playground :material-open-in-new:](https://play.mvl-lang.org){ .md-button .md-button--primary }

---

## How it works

Three lines, because the split matters more than it looks:

1. **Compiling happens on our backend.** Your source is sent to a small Rust
   (axum) service that shells out to the real `mvl` compiler — the same binary
   you would install locally, pinned to a specific release.
2. **Running happens in *your* browser.** The compiler returns WebAssembly, and
   your browser executes it in a Web Worker behind a WASI shim. Our servers
   never run your program.
3. **Validators run on the backend too.** `check`, `prove`, `mcdc`,
   `assurance` and friends return structured JSON, which the frontend renders
   into the assurance pane.

That second point is the one worth remembering: the thing that could loop
forever or eat memory runs on your machine, sandboxed by your browser, not on
ours.

---

## What you can do

- **Multi-file workspaces** — not just a single scratch buffer; `import` across
  files the way a real project does.
- **Validate ▾** — run any of the assurance tools individually and see what each
  one actually claims.
- **Run vs Validate output** — separate tabs, because "it ran" and "it is
  proven" are different questions.
- **Compile Output always visible** — diagnostics are the product, so they are
  never hidden behind a tab.
- **Curated examples** — chosen to show the assurance surface rather than to
  look pretty, including ones that deliberately fail.
- **Your workspace persists** in `localStorage`, so a refresh does not lose
  your work.

---

## What you should know

Short and honest, rather than a click-through you would not read.

**Where your code goes.** Source is sent to our backend to be compiled. We do
not persist it — your workspace lives in your browser's `localStorage` and
stays there. Compiled output is returned to you and executed by your browser.

**Do not paste anything sensitive.** No production secrets, customer data, or
credentials. This is a public demo surface, not a private workspace. If you
need to compile something confidential, run the compiler locally — it is the
same binary, and [installing it](install.md) takes a minute.

**There are limits, and they are deliberate.** Requests are rate limited per
IP, request bodies are capped, and compiles are bounded by wall clock — a
runaway compile is terminated rather than allowed to consume the box. If you
hit a limit during honest use, that is a bug worth reporting.

**No warranty.** The playground is a demonstration. It may change, break, or be
taken down. MVL itself is licensed in the
[mvl repository](https://github.com/mvl-lang/mvl); your code remains yours.

**The compiler version is pinned** per playground release and shown in the
footer, so a result you get today is reproducible against that exact version.

---

## Reporting problems

It matters which repository, because they are different codebases:

- :material-bug: **Something wrong with the playground itself** — the editor,
  the panes, a 500 — [mvl-playground issues](https://github.com/mvl-lang/mvl-playground/issues)
- :material-bug: **Something wrong with the language or compiler** — a bad
  diagnostic, a proof that should have succeeded —
  [mvl issues](https://github.com/mvl-lang/mvl/issues)
- :material-shield-alert: **A security issue** — please disclose privately, see
  [Contact](community/contact.md)

---

## Where next

- [Getting Started](getting-started.md) — the same first program, on your own machine
- [Install](install.md) — get the compiler locally
- [The 11 Requirements](why/requirements.md) — what MVL is actually trying to guarantee
- [Language Reference](docs/reference.md) — the full surface
- :simple-discord: [Discord](https://discord.gg/BuWfh7A2A) — ask questions, show what you built
