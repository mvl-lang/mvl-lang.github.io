#!/bin/sh
# MVL installer — https://mvl-lang.org
#
# Usage:
#   curl -fsSL https://mvl-lang.org/install.sh | sh
#   curl -fsSL https://mvl-lang.org/install.sh | sh -s -- --check
#
# Options:
#   --check, -c        Verify prerequisites and exit (nothing installed)
#
# Environment variables:
#   MVL_INSTALL_DIR    — install location (default: ~/.local/bin)
#   MVL_VERSION        — version/tag to build (default: latest release)
#   MVL_NO_MODIFY_PATH — set to 1 to skip PATH modification
#
# This script:
#   1. Detects your OS and architecture
#   2. Checks for Rust toolchain (installs if missing)
#   3. Clones/updates the MVL repository
#   4. Builds from source with cargo
#   5. Installs to ~/.local/bin/mvl
#   6. Adds to PATH (with your permission)
#
# Supported platforms:
#   - macOS (Apple Silicon, Intel)
#   - Linux (x86_64, aarch64)
#
# License: Apache-2.0

set -eu

# ── Argument parsing ───────────────────────────────────────────────────

CHECK_ONLY=0
while [ $# -gt 0 ]; do
  case "$1" in
    --check|-c) CHECK_ONLY=1 ;;
    --help|-h)
      sed -n '2,26p' "$0" 2>/dev/null | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      printf "Unknown option: %s\n" "$1" >&2
      printf "Try: curl -fsSL https://mvl-lang.org/install.sh | sh -s -- --help\n" >&2
      exit 2
      ;;
  esac
  shift
done

# ── Constants ──────────────────────────────────────────────────────────

MVL_REPO="mvl-lang/mvl"
MVL_INSTALL_DIR="${MVL_INSTALL_DIR:-$HOME/.local/bin}"
MVL_VERSION="${MVL_VERSION:-latest}"
MVL_BUILD_DIR="${MVL_BUILD_DIR:-$HOME/.mvl/src}"

# ── Colors (only if terminal) ─────────────────────────────────────────

if [ -t 1 ]; then
  BOLD='\033[1m'
  DIM='\033[2m'
  PURPLE='\033[1;35m'
  GREEN='\033[1;32m'
  RED='\033[1;31m'
  RESET='\033[0m'
else
  BOLD=''
  DIM=''
  PURPLE=''
  GREEN=''
  RED=''
  RESET=''
fi

info()  { printf "${PURPLE}mvl${RESET} %s\n" "$1"; }
ok()    { printf "${GREEN}  ✓${RESET} %s\n" "$1"; }
err()   { printf "${RED}  ✗${RESET} %s\n" "$1" >&2; }
abort() { err "$1"; exit 1; }

# ── Platform detection ─────────────────────────────────────────────────

detect_platform() {
  OS="$(uname -s)"
  ARCH="$(uname -m)"

  case "$OS" in
    Darwin) OS="apple-darwin" ;;
    Linux)  OS="unknown-linux-gnu" ;;
    *)      abort "Unsupported OS: $OS. MVL supports macOS and Linux." ;;
  esac

  case "$ARCH" in
    x86_64)  ARCH="x86_64" ;;
    aarch64) ARCH="aarch64" ;;
    arm64)   ARCH="aarch64" ;;
    *)       abort "Unsupported architecture: $ARCH. MVL supports x86_64 and aarch64." ;;
  esac

  TARGET="${ARCH}-${OS}"
}

# ── Check prerequisites ────────────────────────────────────────────────

check_rust() {
  # Rustup installs to $HOME/.cargo/bin but with --no-modify-path leaves
  # the user's shell unchanged.  A prior partial install would have cargo
  # on disk but not on PATH in a fresh non-interactive shell, causing
  # rustup to needlessly re-run.  Source ~/.cargo/env if it exists, then
  # look at both PATH and the standard rustup location.
  if [ -f "$HOME/.cargo/env" ]; then
    # shellcheck source=/dev/null
    . "$HOME/.cargo/env"
  fi
  if command -v cargo >/dev/null 2>&1 || [ -x "$HOME/.cargo/bin/cargo" ]; then
    RUSTC="$(command -v rustc || echo "$HOME/.cargo/bin/rustc")"
    ok "Rust toolchain found: $("$RUSTC" --version 2>/dev/null || echo 'unknown')"
    return 0
  fi
  if [ "$CHECK_ONLY" = "1" ]; then
    printf "  ${RED}✗${RESET} Rust toolchain NOT found\n"
    printf "      The installer will fetch it via rustup on a real run.\n"
    return 1
  fi
  return 1
}

install_rust() {
  info "Rust toolchain not found. Installing via rustup..."
  curl --proto '=https' --tlsv1.2 -sSf https://sh.rustup.rs | sh -s -- -y --no-modify-path
  # shellcheck source=/dev/null
  . "$HOME/.cargo/env"
  ok "Rust installed"
}

check_git() {
  if command -v git >/dev/null 2>&1; then
    ok "git found: $(command -v git)"
    return 0
  fi
  if [ "$CHECK_ONLY" = "1" ]; then
    printf "  ${RED}✗${RESET} git NOT found\n"
    printf "      Install via your package manager (git-scm.com)\n"
    return 1
  fi
  abort "git is required but not found. Please install git first."
}

# The Z3 install command for the current platform.  Prints one line
# with the recommended command, or a hint if we can't detect the
# platform's package manager.
z3_install_hint() {
  case "$(uname -s)" in
    Darwin)  printf "brew install z3\n" ;;
    Linux)
      if command -v apt-get >/dev/null 2>&1; then
        printf "sudo apt-get install -y libz3-dev z3\n"
      elif command -v dnf >/dev/null 2>&1; then
        printf "sudo dnf install -y z3 z3-devel\n"
      elif command -v pacman >/dev/null 2>&1; then
        printf "sudo pacman -S --noconfirm z3\n"
      elif command -v apk >/dev/null 2>&1; then
        printf "sudo apk add z3 z3-dev\n"
      else
        printf "(Use your distribution's package manager to install z3 + z3-dev/devel)\n"
      fi
      ;;
    *) printf "(Install z3 for your platform — https://github.com/Z3Prover/z3)\n" ;;
  esac
}

# The MVL compiler's refinement solver uses z3-sys, which links against
# the Z3 C library at build time.  Cargo cannot install system libraries,
# so we detect and instruct — auto-install would need sudo and package-
# manager guessing that is best left to the user.
check_z3() {
  if command -v z3 >/dev/null 2>&1; then
    ok "Z3 solver found: $(z3 --version 2>/dev/null | head -1)"
    return 0
  fi

  if [ "$CHECK_ONLY" = "1" ]; then
    printf "  ${RED}✗${RESET} Z3 solver NOT found\n"
    printf "      %s" "$(z3_install_hint)"
    return 1
  fi

  printf "\n${RED}Z3 solver not found.${RESET}\n"
  printf "MVL's refinement checker depends on Z3.  Install it before continuing:\n\n"
  printf "  %s" "$(z3_install_hint)"
  printf "\nThen re-run this script.\n\n"
  exit 1
}

# ── Clone or update repo ───────────────────────────────────────────────

fetch_source() {
  mkdir -p "$(dirname "$MVL_BUILD_DIR")"

  if [ -d "$MVL_BUILD_DIR/.git" ]; then
    info "Updating MVL source..."
    cd "$MVL_BUILD_DIR"
    git fetch --tags --quiet
  else
    info "Cloning MVL repository..."
    rm -rf "$MVL_BUILD_DIR"
    git clone --quiet "https://github.com/${MVL_REPO}.git" "$MVL_BUILD_DIR"
    cd "$MVL_BUILD_DIR"
  fi

  # Checkout specific version or latest release
  if [ "$MVL_VERSION" = "latest" ]; then
    # Get the latest release tag
    LATEST_TAG=$(git describe --tags --abbrev=0 2>/dev/null || echo "")
    if [ -n "$LATEST_TAG" ]; then
      git checkout --quiet "$LATEST_TAG"
      ok "Using release: $LATEST_TAG"
    else
      git checkout --quiet main
      ok "Using branch: main (no releases found)"
    fi
  else
    git checkout --quiet "$MVL_VERSION"
    ok "Using version: $MVL_VERSION"
  fi
}

# ── Build ──────────────────────────────────────────────────────────────

build_mvl() {
  info "Building MVL (this may take a few minutes)..."
  cd "$MVL_BUILD_DIR"

  # Ensure cargo is in PATH (in case we just installed Rust)
  if [ -f "$HOME/.cargo/env" ]; then
    # shellcheck source=/dev/null
    . "$HOME/.cargo/env"
  fi

  cargo build --release --quiet 2>/dev/null || cargo build --release
  ok "Build complete"
}

# ── Install ────────────────────────────────────────────────────────────

install_binary() {
  mkdir -p "$MVL_INSTALL_DIR"
  cp "$MVL_BUILD_DIR/target/release/mvl" "$MVL_INSTALL_DIR/mvl"
  chmod +x "$MVL_INSTALL_DIR/mvl"
  ok "Installed to $MVL_INSTALL_DIR/mvl"
}

# ── PATH setup ─────────────────────────────────────────────────────────

setup_path() {
  if [ "${MVL_NO_MODIFY_PATH:-0}" = "1" ]; then
    return
  fi

  # Check if already in PATH
  case ":$PATH:" in
    *":$MVL_INSTALL_DIR:"*) return ;;
  esac

  SHELL_NAME="$(basename "${SHELL:-sh}")"
  case "$SHELL_NAME" in
    bash) RC="$HOME/.bashrc" ;;
    zsh)  RC="$HOME/.zshrc" ;;
    fish) RC="$HOME/.config/fish/config.fish" ;;
    *)    RC="" ;;
  esac

  if [ -n "$RC" ] && [ -f "$RC" ]; then
    if ! grep -q "$MVL_INSTALL_DIR" "$RC" 2>/dev/null; then
      if [ "$SHELL_NAME" = "fish" ]; then
        printf '\n# MVL\nfish_add_path %s\n' "$MVL_INSTALL_DIR" >> "$RC"
      else
        printf '\n# MVL\nexport PATH="%s:$PATH"\n' "$MVL_INSTALL_DIR" >> "$RC"
      fi
      ok "Added $MVL_INSTALL_DIR to PATH in $RC"
      info "Run 'source $RC' or restart your shell"
    fi
  else
    info "Add this to your shell config:"
    printf "    export PATH=\"%s:\$PATH\"\n" "$MVL_INSTALL_DIR"
  fi
}

# ── Main ───────────────────────────────────────────────────────────────

main() {
  printf "\n"
  printf "${PURPLE}${BOLD}  MVL — Maximum Verifiable Language${RESET}\n"
  printf "${DIM}  https://mvl-lang.org${RESET}\n"
  printf "\n"

  detect_platform
  info "Detected platform: ${TARGET}"
  printf "\n"

  # --check mode: run all prerequisite checks, report status, exit.
  # Nothing on disk is touched.  Non-zero exit iff any prereq missing.
  if [ "$CHECK_ONLY" = "1" ]; then
    printf "${BOLD}Prerequisites:${RESET}\n"
    MISSING=0
    check_git  || MISSING=$((MISSING + 1))
    check_z3   || MISSING=$((MISSING + 1))
    check_rust || MISSING=$((MISSING + 1))
    printf "\n"
    if [ "$MISSING" -eq 0 ]; then
      ok "All prerequisites satisfied.  Run again without --check to install."
      exit 0
    else
      printf "${RED}${MISSING} prerequisite(s) missing.${RESET}  Install them, then re-run without --check.\n"
      exit 1
    fi
  fi

  # Check and install prerequisites
  check_git
  check_z3
  check_rust || install_rust

  printf "\n"

  # Fetch source code
  fetch_source

  printf "\n"

  # Build from source
  build_mvl

  printf "\n"

  # Install binary
  install_binary

  # Setup PATH
  setup_path

  printf "\n"
  VERSION=$("$MVL_INSTALL_DIR/mvl" --version 2>/dev/null || echo "unknown")
  ok "MVL installed successfully! ($VERSION)"
  printf "\n"
  info "Run 'mvl --version' to verify"
  info "Run 'mvl help' to get started"
  printf "\n"
}

main "$@"
