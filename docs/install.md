# Install MVL

## Quick Install

```bash
curl -fsSL https://mvl-lang.org/install.sh | sh
```

This installs the `mvl` binary to `~/.mvl/bin/` and adds it to your PATH.

## Manual Install

Download the latest release for your platform from [GitHub Releases](https://github.com/mvl-lang/mvl/releases):

| Platform | Architecture | Download |
|----------|-------------|----------|
| macOS | Apple Silicon (M1/M2/M3) | `mvl-aarch64-apple-darwin.tar.gz` |
| macOS | Intel | `mvl-x86_64-apple-darwin.tar.gz` |
| Linux | x86_64 | `mvl-x86_64-unknown-linux-gnu.tar.gz` |

Extract and add to PATH:

```bash
tar xzf mvl-*.tar.gz
sudo mv mvl /usr/local/bin/
```

## From Source

Requires [Rust](https://rustup.rs/) (stable toolchain):

```bash
git clone https://github.com/mvl-lang/mvl.git
cd mvl
make build
```

## Verify Installation

```bash
mvl --version
# mvl 0.161.1
```

## Editor Support

MVL provides an LSP server for editor integration:

```bash
mvl lsp  # starts the language server
```

Configure your editor to use `mvl lsp` as the language server for `.mvl` files.
