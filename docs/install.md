# Install MVL

## Quick Install

```bash
curl -fsSL https://mvl-lang.org/install.sh | sh
```

This:

1. Installs Rust if not present (via [rustup](https://rustup.rs/))
2. Clones and builds MVL from source
3. Installs the `mvl` binary to `~/.local/bin/`
4. Adds `~/.local/bin` to your PATH

No sudo required.

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `MVL_INSTALL_DIR` | `~/.local/bin` | Where to install the binary |
| `MVL_VERSION` | `latest` | Version/tag to build (e.g., `v0.197.1`) |
| `MVL_BUILD_DIR` | `~/.mvl/src` | Where to clone source |
| `MVL_NO_MODIFY_PATH` | `0` | Set to `1` to skip PATH modification |

Example: install a specific version to a custom location:

```bash
MVL_VERSION=v0.197.1 MVL_INSTALL_DIR=/opt/mvl/bin \
  curl -fsSL https://mvl-lang.org/install.sh | sh
```

## Manual Build

Requires [Rust](https://rustup.rs/) (stable toolchain) and git:

```bash
git clone https://github.com/mvl-lang/mvl.git
cd mvl
cargo build --release
cp target/release/mvl ~/.local/bin/
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
