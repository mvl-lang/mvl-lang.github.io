# mvl-lang.org

Website for the MVL programming language — [mvl-lang.org](https://mvl-lang.org)

## What is MVL?

MVL (Minimum Verification Language) is a programming language where the compiler verifies 11 safety and correctness properties at compile time:

1. Type safety
2. Memory safety
3. No null
4. Exhaustive matching
5. Bounds safety
6. Ownership
7. Error visibility
8. Termination
9. Effect tracking
10. Refinement types
11. Information flow control

## Repository Structure

```
docs/           # MkDocs source files
  getting-started.md
  install.md
  language/     # Language documentation
  community/    # Community resources
mkdocs.yml      # MkDocs configuration
```

## Development

### Prerequisites

- Python 3.12+
- [MkDocs Material](https://squidfunk.github.io/mkdocs-material/)

### Local Development

```bash
pip install mkdocs-material
mkdocs serve
```

Open http://localhost:8000

### Deployment

The site deploys automatically via GitHub Actions on push to `main`. See `.github/workflows/pages.yml`.

## Related Repositories

- [LAB271/mvl_language](https://github.com/LAB271/mvl_language) — Compiler source code
- [mvl-lang/homebrew-mvl](https://github.com/mvl-lang/homebrew-mvl) — Homebrew tap

## License

Documentation is licensed under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/).
