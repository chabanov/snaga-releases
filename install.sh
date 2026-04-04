#!/bin/sh
# Snaga AI Coding Agent — installer
# Usage: curl -fsSL https://raw.githubusercontent.com/chabanov/snaga-releases/main/install.sh | bash
set -e

REPO="chabanov/snaga-releases"
INSTALL_DIR="${SNAGA_HOME:-$HOME/.snaga}/bin"

# Colors (safe for non-tty too)
if [ -t 1 ]; then
  RED='\033[0;31m'; GREEN='\033[0;32m'; CYAN='\033[0;36m'
  DIM='\033[0;90m'; BOLD='\033[1m'; NC='\033[0m'
else
  RED=''; GREEN=''; CYAN=''; DIM=''; BOLD=''; NC=''
fi

info() { printf "${CYAN}%s${NC}\n" "$1"; }
ok()   { printf "${GREEN}%s${NC}\n" "$1"; }
err()  { printf "${RED}Error: %s${NC}\n" "$1" >&2; exit 1; }
dim()  { printf "${DIM}%s${NC}\n" "$1"; }

# ── Platform detection ──────────────────────────

detect_target() {
  local os arch

  case "$(uname -s)" in
    Darwin) os="apple-darwin" ;;
    Linux)  os="unknown-linux-gnu" ;;
    *)      err "Unsupported OS: $(uname -s)" ;;
  esac

  case "$(uname -m)" in
    x86_64|amd64)  arch="x86_64" ;;
    aarch64|arm64) arch="aarch64" ;;
    *)             err "Unsupported architecture: $(uname -m)" ;;
  esac

  echo "${arch}-${os}"
}

# ── HTTP fetch (curl or wget) ───────────────────

fetch() {
  local url="$1" dest="$2"
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL -o "$dest" "$url"
  elif command -v wget >/dev/null 2>&1; then
    wget -qO "$dest" "$url"
  else
    err "curl or wget is required"
  fi
}

fetch_text() {
  if command -v curl >/dev/null 2>&1; then
    curl -fsSL "$1"
  else
    wget -qO- "$1"
  fi
}

# ── Version resolution ──────────────────────────

resolve_version() {
  if [ -n "$SNAGA_VERSION" ]; then
    echo "$SNAGA_VERSION"
    return
  fi

  local tag
  tag=$(fetch_text "https://api.github.com/repos/${REPO}/releases/latest" \
    | grep '"tag_name"' | head -1 | sed 's/.*"tag_name": *"//;s/".*//')

  [ -z "$tag" ] && err "Cannot resolve latest version. Set SNAGA_VERSION=v0.x.x manually."
  echo "$tag"
}

# ── Checksum verification ───────────────────────

verify() {
  local file="$1" expected="$2" actual

  if command -v shasum >/dev/null 2>&1; then
    actual=$(shasum -a 256 "$file" | awk '{print $1}')
  elif command -v sha256sum >/dev/null 2>&1; then
    actual=$(sha256sum "$file" | awk '{print $1}')
  else
    dim "  (skipping checksum — no shasum/sha256sum found)"
    return 0
  fi

  [ "$actual" = "$expected" ] || err "Checksum mismatch!\n  Expected: $expected\n  Got:      $actual"
}

# ── Main ────────────────────────────────────────

main() {
  printf "\n${BOLD}   S N A G A${NC}  ${DIM}installer${NC}\n\n"

  local target version archive base_url tmp

  target=$(detect_target)
  version=$(resolve_version)
  archive="snaga-${target}.tar.gz"
  base_url="https://github.com/${REPO}/releases/download/${version}"

  info "  Version:  ${version}"
  info "  Platform: ${target}"
  echo ""

  tmp=$(mktemp -d)
  trap 'rm -rf "$tmp"' EXIT

  # Download checksums
  dim "  Downloading checksums..."
  fetch "${base_url}/sha256sums.txt" "${tmp}/sha256sums.txt"
  local expected
  expected=$(grep "${archive}" "${tmp}/sha256sums.txt" 2>/dev/null | awk '{print $1}')

  # Download binary
  dim "  Downloading ${archive}..."
  fetch "${base_url}/${archive}" "${tmp}/${archive}"

  # Verify
  if [ -n "$expected" ]; then
    dim "  Verifying checksum..."
    verify "${tmp}/${archive}" "$expected"
  fi

  # Install
  dim "  Installing to ${INSTALL_DIR}..."
  mkdir -p "$INSTALL_DIR"
  tar xzf "${tmp}/${archive}" -C "$tmp"
  mv "${tmp}/snaga" "${INSTALL_DIR}/snaga"
  chmod +x "${INSTALL_DIR}/snaga"

  echo ""
  ok "  Snaga ${version} installed successfully!"
  echo ""

  # Auto-add to PATH
  case ":$PATH:" in
    *":${INSTALL_DIR}:"*) ;;
    *)
      local rc rc_path line
      line="export PATH=\"${INSTALL_DIR}:\$PATH\""

      case "${SHELL:-/bin/sh}" in
        */zsh)  rc="~/.zshrc";  rc_path="$HOME/.zshrc" ;;
        */bash) rc="~/.bashrc"; rc_path="$HOME/.bashrc" ;;
        */fish) rc="~/.config/fish/config.fish"; rc_path="$HOME/.config/fish/config.fish" ;;
        *)      rc=""; rc_path="" ;;
      esac

      if [ -n "$rc_path" ]; then
        # Add to rc file if not already there
        if ! grep -qF "${INSTALL_DIR}" "$rc_path" 2>/dev/null; then
          echo "" >> "$rc_path"
          if [ "$(basename "${SHELL:-sh}")" = "fish" ]; then
            echo "fish_add_path ${INSTALL_DIR}" >> "$rc_path"
          else
            echo "$line" >> "$rc_path"
          fi
          ok "  Added to ${rc}"
        fi
        dim "  Restart your terminal or run: source ${rc}"
        echo ""
      else
        info "  Add to your PATH manually:"
        echo "    $line"
        echo ""
      fi
      ;;
  esac

  dim "  Run 'snaga' to start."
  echo ""
}

main "$@"
