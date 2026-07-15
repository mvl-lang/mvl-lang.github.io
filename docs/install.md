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

### Verify the script before running

For security-conscious users who want to inspect or checksum the install script before running it:

```bash
# Download to a file instead of piping to sh
curl -fsSL https://mvl-lang.org/install.sh       -o /tmp/mvl-install.sh
curl -fsSL https://mvl-lang.org/install.sh.sha256 -o /tmp/mvl-install.sh.sha256

# Verify the checksum
( cd /tmp && shasum -a 256 -c mvl-install.sh.sha256 )
# → mvl-install.sh: OK

# Read the source (260-ish lines of POSIX sh)
less /tmp/mvl-install.sh

# Run when satisfied
sh /tmp/mvl-install.sh
```

The sidecar `install.sh.sha256` is regenerated whenever `install.sh` changes and published from the same site.

### Trust chain — what protects against MITM

The install path is protected by several independent layers:

| Layer | Where | What it defends |
|-------|-------|-----------------|
| **HTTPS + system CA validation** | curl connects to `mvl-lang.org`, `github.com`, `sh.rustup.rs` | Passive interception; forged endpoints |
| **`--proto '=https' --tlsv1.2`** | All curl calls in the script | TLS downgrade attacks; unencrypted redirect chains |
| **Certificate Transparency** | GitHub, most CAs | Detects rogue certs issued for github.com |
| **`install.sh.sha256`** | Published alongside `install.sh` | Tampering with the script in transit or on the site |
| **Git content-addressed SHAs** | `git clone` and `git checkout` | Tampering with source code after clone (git verifies every object) |
| **`Cargo.lock`** | Present in the `mvl-lang/mvl` repo | Tampering with Rust dependencies (cargo verifies every crate SHA) |
| **Homebrew formula SHA256s** | For users on the [tap](https://github.com/mvl-lang/homebrew-mvl) | Tampering with the release binary or stdlib tarballs |

**What's NOT yet in place** (candidate for future hardening):

- **GPG-signed release tags** — anyone with GitHub write access could rewrite a tag today. Signing tags with a project key would let you verify tag integrity independent of GitHub's own controls.
- **Sigstore / cosign for release artifacts** — modern replacement for GPG signing; publishes signatures to a public transparency log. Not yet on our release pipeline.
- **Reproducible-build attestations** — proving that the binary you download was actually built from the source tag it claims. This is a Phase 9 / DO-178C certification concern more than a general-user concern.

If you're deploying MVL into a safety-critical environment where the above matters, use the [Homebrew tap](https://github.com/mvl-lang/homebrew-mvl) (SHAs pinned in the formula, review-gated by tap PRs) rather than `curl | sh`.

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
