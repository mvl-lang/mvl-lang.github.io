# Install MVL

## Homebrew (macOS Apple Silicon)

Fastest path — installs a pre-built binary in seconds:

```bash
brew tap mvl-lang/mvl
brew trust mvl-lang/mvl    # Homebrew 6.x requires trusting third-party taps
brew install mvl
```

Verify:

```bash
mvl --version    # → mvl 1.0.0
mvl --help
```

The Homebrew formula installs the compiler binary, standard library, and Rust FFI runtime. `MVL_HOME` is configured automatically by a wrapper in `bin/mvl`. See [`mvl-lang/homebrew-mvl`](https://github.com/mvl-lang/homebrew-mvl) for what the tap ships and how to update it.

!!! note "About `brew trust`"
    Homebrew 6.0 introduced a trust step for third-party taps to protect users from unreviewed formulae. This is a one-time step per tap. If you skip it, `brew install` will refuse to load the formula with a message telling you what to run.

Platforms currently supported by the tap:

| Platform | Status |
|----------|--------|
| macOS on Apple Silicon (arm64) | ✅ Prebuilt binary |
| macOS on Intel (x86_64) | ⏳ Coming — use the install script below |
| Linux / Windows / other | ⏳ Coming — use the install script below |

## Universal install script (build from source)

Works on any platform with Rust:

```bash
curl -fsSL https://mvl-lang.org/install.sh | sh
```

This:

1. Verifies system prerequisites (see below)
2. Installs Rust if not present (via [rustup](https://rustup.rs/))
3. Clones and builds MVL from source
4. Installs the `mvl` binary to `~/.local/bin/`
5. Adds `~/.local/bin` to your PATH

No sudo required for MVL itself.

### Check before installing

To verify what's already on your system without installing anything, run with `--check`:

```bash
curl -fsSL https://mvl-lang.org/install.sh | sh -s -- --check
```

Sample output:

```
Prerequisites:
  ✓ git found: /usr/bin/git
  ✗ Z3 solver NOT found
      brew install z3
  ✓ Rust toolchain found: rustc 1.83.0
```

Exit code is non-zero if anything is missing, so it composes with CI/scripting. Nothing is written to disk in check mode.

### System prerequisites

The script checks for these and stops with a clear install command if missing:

- **git** — for cloning the source
- **Z3** — required by MVL's refinement solver (transitively via `z3-sys`); the script does not attempt to install it because system-package installation requires `sudo`

Install Z3 up front:

| Platform | Command |
|----------|---------|
| macOS (Homebrew) | `brew install z3` |
| Debian / Ubuntu | `sudo apt-get install -y libz3-dev z3` |
| Fedora / RHEL | `sudo dnf install -y z3 z3-devel` |
| Arch | `sudo pacman -S z3` |
| Alpine | `sudo apk add z3 z3-dev` |

## Environment Variables

| Variable | Default | Description |
|----------|---------|-------------|
| `MVL_INSTALL_DIR` | `~/.local/bin` | Where to install the binary |
| `MVL_VERSION` | `latest` | Version/tag to build (e.g., `v1.0.0`) |
| `MVL_BUILD_DIR` | `~/.mvl/src` | Where to clone source |
| `MVL_NO_MODIFY_PATH` | `0` | Set to `1` to skip PATH modification |

Example: install a specific version to a custom location:

```bash
MVL_VERSION=v1.0.0 MVL_INSTALL_DIR=/opt/mvl/bin \
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
# mvl 1.0.0
```

## Editor Support

MVL provides an LSP server for editor integration:

```bash
mvl lsp  # starts the language server
```

Configure your editor to use `mvl lsp` as the language server for `.mvl` files.
