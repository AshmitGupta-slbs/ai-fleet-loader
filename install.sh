#!/usr/bin/env bash
# One-command bootstrap for the Local Agent kit.
#
#   curl -fsSL <RAW_URL>/install.sh | bash
#
# Installs prerequisites (Node + Claude Code CLI), fetches the kit, and runs setup.sh.
# Safe to re-run. macOS & Linux are first-class; on Windows use WSL.
#
# Override defaults with env vars:
#   KIT_REPO=<git url>   (where the kit lives)
#   TARGET=<dir>         (where to clone it; default ~/fleet-local)
set -euo pipefail

# --- where to get the kit and where to put it ------------------------------
KIT_REPO="${KIT_REPO:-https://github.com/AshmitGupta-slbs/ai-fleet-loader.git}"
TARGET="${TARGET:-$HOME/ai-fleet-loader}"

say()  { printf '\033[1;36m%s\033[0m\n' "$*"; }
ok()   { printf '\033[1;32m✓ %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m! %s\033[0m\n' "$*"; }
die()  { printf '\033[1;31m✗ %s\033[0m\n' "$*" >&2; exit 1; }

case "$(uname -s)" in
  Darwin) OS=mac ;;
  Linux)  OS=linux ;;
  *) die "Unsupported OS '$(uname -s)'. On Windows, run this inside WSL (Ubuntu)." ;;
esac
ok "Platform: $OS"

have() { command -v "$1" >/dev/null 2>&1; }

# --- git -------------------------------------------------------------------
have git || die "git is required. Install it (mac: 'xcode-select --install'; linux: 'sudo apt install git') and re-run."

# --- curl & python3 (needed by the fleet skill) ----------------------------
have curl    || warn "curl not found — needed by the 'fleet' skill. Install it."
have python3 || warn "python3 not found — needed by the 'fleet' skill for safe JSON. Install Python 3."

# --- Node.js (for Claude Code + central-skills gateway) --------------------
ensure_node() {
  if have node; then ok "Node.js present ($(node -v))"; return; fi
  say "Installing Node.js…"
  if [ "$OS" = mac ] && have brew; then
    brew install node || true
  elif [ "$OS" = linux ] && have apt-get; then
    sudo apt-get update -y && sudo apt-get install -y nodejs npm || true
  fi
  if ! have node; then
    # Universal, no-sudo fallback: nvm.
    say "Falling back to nvm (no sudo needed)…"
    export NVM_DIR="$HOME/.nvm"
    [ -d "$NVM_DIR" ] || git clone --depth 1 https://github.com/nvm-sh/nvm.git "$NVM_DIR" || true
    # shellcheck disable=SC1090
    [ -s "$NVM_DIR/nvm.sh" ] && . "$NVM_DIR/nvm.sh" && nvm install --lts || true
  fi
  have node || die "Could not install Node.js automatically. Install Node 20+ from https://nodejs.org and re-run."
  ok "Node.js installed ($(node -v))"
}
ensure_node

# --- Claude Code CLI -------------------------------------------------------
if have claude; then
  ok "Claude Code present ($(claude --version 2>/dev/null || echo installed))"
else
  say "Installing Claude Code CLI…"
  npm install -g @anthropic-ai/claude-code || warn "npm global install failed — you may need 'sudo npm install -g @anthropic-ai/claude-code' or a Node version manager."
  have claude || warn "Claude Code not on PATH yet. If 'claude' isn't found after this, open a new terminal or add npm's global bin to PATH."
fi

# --- fetch / update the kit ------------------------------------------------
if [ -d "$TARGET/.git" ]; then
  say "Updating existing kit at $TARGET…"
  git -C "$TARGET" pull --ff-only || warn "Could not fast-forward $TARGET (local changes?). Continuing with what's there."
elif [ -e "$TARGET" ] && [ -n "$(ls -A "$TARGET" 2>/dev/null || true)" ]; then
  die "$TARGET exists and is not a git checkout. Move it aside or set TARGET=<dir> and re-run."
else
  say "Cloning the kit into $TARGET…"
  git clone "$KIT_REPO" "$TARGET" || die "Clone failed. Check KIT_REPO ($KIT_REPO) and your access."
fi
ok "Kit ready at $TARGET"

# --- run setup (interactive: pod + keys + URL) -----------------------------
chmod +x "$TARGET/setup.sh" "$TARGET/new-skill.sh" "$TARGET/fleet-query.sh" 2>/dev/null || true
say ""
say "Running setup (it will ask for your pod, your personal API key, and the agent URL)…"
say ""
( cd "$TARGET" && ./setup.sh )

say ""
ok "All set. To start your local agent:"
say "    cd $TARGET && claude"
say ""
say "Tip: re-run the installer anytime to update — curl -fsSL https://raw.githubusercontent.com/AshmitGupta-slbs/ai-fleet-loader/main/install.sh | bash"
