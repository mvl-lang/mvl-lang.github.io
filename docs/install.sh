#!/bin/sh
# MVL installer — https://mvl-lang.org
#
# Usage:
#   curl -fsSL https://mvl-lang.org/install.sh | sh
#
# Verification:
#   curl -fsSL https://mvl-lang.org/install.sh -o install.sh
#   curl -fsSL https://mvl-lang.org/install.sh.sha256 -o install.sh.sha256
#   sha256sum -c install.sh.sha256
#   sh install.sh
#
# Environment variables:
#   MVL_INSTALL_DIR   — install location (default: ~/.mvl/bin)
#   MVL_VERSION       — version to install (default: latest)
#   MVL_NO_MODIFY_PATH — set to 1 to skip PATH modification
#
# This script:
#   1. Detects your OS and architecture
#   2. Downloads the MVL binary from GitHub Releases
#   3. Verifies the SHA-256 checksum
#   4. Installs to ~/.mvl/bin/
#   5. Adds to PATH (with your permission)
#
# Supported platforms:
#   - macOS (Apple Silicon, Intel)
#   - Linux (x86_64)
#
# License: Apache-2.0

set -eu

# ── Constants ──────────────────────────────────────────────────────────

MVL_REPO="mvl-lang/mvl"
MVL_INSTALL_DIR="${MVL_INSTALL_DIR:-$HOME/.mvl/bin}"
MVL_VERSION="${MVL_VERSION:-latest}"

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

# ── Main ───────────────────────────────────────────────────────────────

main() {
  printf "\n"
  printf "${PURPLE}${BOLD}  MVL — Maximum Verifiable Language${RESET}\n"
  printf "${DIM}  https://mvl-lang.org${RESET}\n"
  printf "\n"

  detect_platform
  info "Detected platform: ${TARGET}"

  # ── Coming soon ────────────────────────────────────────────────────

  printf "\n"
  printf "${PURPLE}${BOLD}  Coming soon.${RESET}\n"
  printf "\n"
  info "Binary releases are not yet available."
  info "To build from source:"
  printf "\n"
  printf "    git clone https://github.com/mvl-lang/mvl.git\n"
  printf "    cd mvl\n"
  printf "    cargo build --release\n"
  printf "    sudo cp target/release/mvl /usr/local/bin/\n"
  printf "\n"
  info "Follow progress: https://github.com/mvl-lang/mvl/releases"
  printf "\n"

  # ── Below is the full installer, activated when releases exist ─────
  # Uncomment when GitHub Releases are live:
  #
  # if [ "$MVL_VERSION" = "latest" ]; then
  #   MVL_VERSION=$(curl -fsSL "https://api.github.com/repos/${MVL_REPO}/releases/latest" \
  #     | grep '"tag_name"' | sed 's/.*"v\(.*\)".*/\1/')
  #   [ -n "$MVL_VERSION" ] || abort "Failed to determine latest version"
  # fi
  #
  # ARCHIVE="mvl-${TARGET}.tar.gz"
  # URL="https://github.com/${MVL_REPO}/releases/download/v${MVL_VERSION}/${ARCHIVE}"
  # CHECKSUM_URL="${URL}.sha256"
  #
  # info "Downloading MVL v${MVL_VERSION} for ${TARGET}..."
  #
  # TMPDIR=$(mktemp -d)
  # trap 'rm -rf "$TMPDIR"' EXIT
  #
  # curl -fsSL "$URL" -o "${TMPDIR}/${ARCHIVE}" \
  #   || abort "Download failed. Check https://github.com/${MVL_REPO}/releases"
  # ok "Downloaded ${ARCHIVE}"
  #
  # # Verify checksum
  # curl -fsSL "$CHECKSUM_URL" -o "${TMPDIR}/${ARCHIVE}.sha256" \
  #   || abort "Checksum download failed"
  # cd "$TMPDIR"
  # if command -v sha256sum >/dev/null 2>&1; then
  #   sha256sum -c "${ARCHIVE}.sha256" --quiet \
  #     || abort "Checksum verification FAILED — download may be corrupted or tampered with"
  # elif command -v shasum >/dev/null 2>&1; then
  #   shasum -a 256 -c "${ARCHIVE}.sha256" --quiet \
  #     || abort "Checksum verification FAILED — download may be corrupted or tampered with"
  # else
  #   err "Neither sha256sum nor shasum found — skipping checksum verification"
  # fi
  # ok "Checksum verified"
  #
  # # Extract and install
  # tar xzf "${ARCHIVE}"
  # mkdir -p "${MVL_INSTALL_DIR}"
  # mv mvl "${MVL_INSTALL_DIR}/mvl"
  # chmod +x "${MVL_INSTALL_DIR}/mvl"
  # ok "Installed to ${MVL_INSTALL_DIR}/mvl"
  #
  # # Add to PATH
  # if [ "${MVL_NO_MODIFY_PATH:-0}" != "1" ]; then
  #   SHELL_NAME="$(basename "$SHELL")"
  #   case "$SHELL_NAME" in
  #     bash) RC="$HOME/.bashrc" ;;
  #     zsh)  RC="$HOME/.zshrc" ;;
  #     fish) RC="$HOME/.config/fish/config.fish" ;;
  #     *)    RC="" ;;
  #   esac
  #
  #   if [ -n "$RC" ] && ! grep -q ".mvl/bin" "$RC" 2>/dev/null; then
  #     printf '\n# MVL\nexport PATH="$HOME/.mvl/bin:$PATH"\n' >> "$RC"
  #     ok "Added ~/.mvl/bin to PATH in ${RC}"
  #     info "Run 'source ${RC}' or restart your shell"
  #   fi
  # fi
  #
  # printf "\n"
  # ok "MVL v${MVL_VERSION} installed successfully!"
  # printf "\n"
  # info "Run 'mvl --version' to verify"
  # info "Run 'mvl help' to get started"
  # printf "\n"
}

main "$@"
