# Editor Support & Tooling

MVL ships a language server, a syntax highlighter, a tree-sitter grammar and
three editor integrations. This page is honest about which are published and
which you install from source — several are the latter.

Everything below lives in [`mvl-lang/mvl-spec`](https://github.com/mvl-lang/mvl-spec)
except the grammar, which has its own repository.

## What is available today

| Tool | Install | Where it comes from |
|------|---------|---------------------|
| **Language server** | `pip install mvl-lsp` | [PyPI · mvl-lsp](https://pypi.org/project/mvl-lsp/) |
| **Syntax highlighter** | `pip install pygments-mvl` | [PyPI · pygments-mvl](https://pypi.org/project/pygments-mvl/) |
| **Neovim** | git, via your plugin manager | [mvl-spec `editors/nvim`](https://github.com/mvl-lang/mvl-spec/tree/main/editors/nvim) |
| **tree-sitter grammar** | git submodule or clone | [mvl-lang/tree-sitter-mvl](https://github.com/mvl-lang/tree-sitter-mvl) |
| **Zed** | dev extension, from source | [mvl-spec `editors/zed`](https://github.com/mvl-lang/mvl-spec/tree/main/editors/zed) |
| **VS Code** | build a VSIX, from source | [mvl-spec `editors/vscode`](https://github.com/mvl-lang/mvl-spec/tree/main/editors/vscode) |

Zed and VS Code are **not yet in their marketplaces.** Zed extensions require a
pull request to `zed-industries/extensions`; the VS Code publish pipeline exists
but is gated pending Marketplace credentials. Both work from source today.

---

## Language server — `mvl-lsp`

Compiler-backed diagnostics. Rather than reimplementing MVL's type rules, it
shells out to `mvl check --stdin --format=json`, so the squiggles you see are
exactly what the compiler reports — including refinement failures, effect
mismatches and IFC violations.

```bash
pip install mvl-lsp
mvl-lsp --help
```

It needs `mvl` on your `PATH`. See [Getting Started](../getting-started.md).

## Syntax highlighting — `pygments-mvl`

A [Pygments](https://pygments.org) lexer. Pygments is the tokeniser behind
mkdocs-material, Sphinx, Hugo/Chroma and Jupyter, so one install covers most of
the documentation ecosystem.

```bash
pip install pygments-mvl
pygmentize -l mvl example.mvl
```

It registers under the `mvl` alias and claims `*.mvl`, so fenced blocks tagged
`mvl` highlight automatically. **This site uses it** — every code block you see
is lexed by it.

Its keyword tables are generated from
[`grammar/grammar.ebnf`](https://github.com/mvl-lang/mvl-spec/blob/main/grammar/grammar.ebnf),
not hand-maintained, so it cannot fall behind the language. The distinction
matters in practice: `end`, `timeout`, `audit`, `self` and `old` are *contextual*
keywords — special in one syntactic position and ordinary identifiers everywhere
else — so `let end = 5;` correctly highlights `end` as a variable.

## Neovim

Install from git with your plugin manager. `lazy.nvim`:

```lua
{
  "mvl-lang/mvl-spec",
  ft = "mvl",
  config = function()
    require("mvl").setup()
  end,
}
```

You also need the tree-sitter grammar as a sibling checkout of `mvl-spec` — the
plugin resolves it at runtime. `:checkhealth mvl` reports whether it found the
grammar, the parser and `mvl` on your `PATH`.

Provides highlighting, indentation, folding and `mvl-lsp` registration.

## Zed

The extension declares the grammar by commit, so Zed fetches
`tree-sitter-mvl` for you. Install as a dev extension:

```bash
git clone https://github.com/mvl-lang/mvl-spec
# Zed: cmd-shift-p -> "zed: install dev extension" -> pick mvl-spec/editors/zed
```

Provides highlighting, indentation and `mvl-lsp` as a registered language server.

## VS Code

Not on the Marketplace yet. Build and install locally:

```bash
git clone https://github.com/mvl-lang/mvl-spec
cd mvl-spec/editors/vscode
npx @vscode/vsce package
code --install-extension mvl-*.vsix
```

VS Code uses a TextMate grammar rather than tree-sitter, so its highlighting is
regex-based and slightly coarser than the other editors'. Its keyword patterns
are generated from the same EBNF.

## tree-sitter grammar

[`mvl-lang/tree-sitter-mvl`](https://github.com/mvl-lang/tree-sitter-mvl) — the
grammar consumed by Neovim and Zed. Bindings for C, Node, Python, Rust and Swift.
Not yet published to npm or crates.io; clone or vendor it as a submodule.

```bash
git clone https://github.com/mvl-lang/tree-sitter-mvl
cd tree-sitter-mvl && tree-sitter generate && tree-sitter test
```

## How these stay in sync

Every keyword table above — the Pygments lexer, the VS Code TextMate patterns,
the tree-sitter highlight queries for both Neovim and Zed — is **generated** from
one file:
[`grammar/grammar.ebnf`](https://github.com/mvl-lang/mvl-spec/blob/main/grammar/grammar.ebnf).

`mvl-spec`'s CI regenerates all of them on every pull request and fails if any
committed artifact differs. Editing a generated file directly is a build failure.

This is deliberate, and it is recent. These lists were hand-copied across five
artifacts until spec 0.1.4, and all five had drifted — two of them highlighted
labels the language does not have, and one highlighted a function-level modifier
the grammar explicitly denies. Generation replaced a convention with a check.

## Versions

Editor integrations and tools are versioned in lockstep with the spec. The
version you install may lag the spec release if the relevant publish step has not
run — the table at the top is the reliable statement of what exists.

## See Also

- [Getting Started](../getting-started.md) — installing the compiler
- [Formal Grammar](../language/grammar.md) — the EBNF these tools generate from
- [Contributing](../community/contributing.md)
