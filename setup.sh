#!/usr/bin/env bash
# Local Agent starter-kit setup.
# Wires this directory into a ready-to-run Claude Code project:
#   - the LIVE, data-capable fleet agent via your personal API key (the `fleet` skill → POST /query)
#   - central skills via the read-only MCP Skills Gateway (.mcp.json) — optional, on demand
#   - personal skills in .claude/skills/ (a REAL dir — auto-discovered + hot-reloaded by Claude Code)
#   - a pod persona in CLAUDE.md
# Idempotent. Never writes to the gateway or the central repo.
set -euo pipefail

GATEWAY_URL="https://saaslabs-agent-skills-production.up.railway.app/mcp/"
GATEWAY_HEALTH="https://saaslabs-agent-skills-production.up.railway.app/health"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$HERE"

say()  { printf '\033[1;36m%s\033[0m\n' "$*"; }
ok()   { printf '\033[1;32m✓ %s\033[0m\n' "$*"; }
warn() { printf '\033[1;33m! %s\033[0m\n' "$*"; }

# --- load any existing .env so re-runs keep prior answers ------------------
[ -f .env ] && set -a && . ./.env && set +a || true

# --- pod -------------------------------------------------------------------
POD="${POD:-}"
if [ -z "$POD" ]; then
  echo "Which pod is this local agent? (dwight | jim | toby | ryan | pam)"
  read -r -p "Pod [dwight]: " POD || true
  POD="${POD:-dwight}"
fi
POD="$(printf '%s' "$POD" | tr '[:upper:]' '[:lower:]')"
# Default deployed base URL per pod. These are DEPLOYMENT-SPECIFIC — the value
# shown to the admin in the agent's "HTTP & API" tab is authoritative. Edit the
# placeholders below if your URLs differ, or just paste the right URL when prompted.
case "$POD" in
  dwight) POD_TITLE="Analytics & Data"; POD_DOMAIN="BigQuery / Amplitude / Tableau / GA4 analytics"; POD_URL_DEFAULT="https://dwight-schrute.up.railway.app/agents/dwight" ;;
  jim)    POD_TITLE="HubSpot CRM & RevOps"; POD_DOMAIN="HubSpot CRM architecture and revenue operations"; POD_URL_DEFAULT="https://jim-halpert.up.railway.app/agents/jim" ;;
  toby)   POD_TITLE="HR & People Ops"; POD_DOMAIN="HR and people-operations policies"; POD_URL_DEFAULT="https://toby-flenderson.up.railway.app/agents/toby" ;;
  ryan)   POD_TITLE="Marketing"; POD_DOMAIN="marketing copy, messaging and content validation"; POD_URL_DEFAULT="https://ryan-howard.up.railway.app/agents/ryan" ;;
  pam)    POD_TITLE="General"; POD_DOMAIN="general-purpose, cross-functional requests"; POD_URL_DEFAULT="https://pam-beesly.up.railway.app/agents/pam" ;;
  *) echo "Unknown pod '$POD'. Choose: dwight | jim | toby | ryan | pam"; exit 1 ;;
esac
ok "Pod: $POD ($POD_TITLE)"

# --- agent base URL --------------------------------------------------------
# Where the deployed agent lives. The /query path is appended automatically.
if [ -z "${AGENT_BASE_URL:-}" ]; then
  echo "Deployed agent base URL (from the admin 'HTTP & API' tab; '/query' is added automatically)."
  read -r -p "Agent base URL [$POD_URL_DEFAULT]: " AGENT_BASE_URL || true
  AGENT_BASE_URL="${AGENT_BASE_URL:-$POD_URL_DEFAULT}"
fi
AGENT_BASE_URL="${AGENT_BASE_URL%/}"
ok "Agent base URL: $AGENT_BASE_URL"

# --- keys ------------------------------------------------------------------
# Personal API key — your access to the live agent (admin: People & Keys → New key).
if [ -z "${FLEET_API_KEY:-}" ]; then
  read -r -p "Your personal fleet API key (admin → People & Keys → New key): " FLEET_API_KEY || true
fi
[ -n "${FLEET_API_KEY:-}" ] || warn "No personal key set — the 'fleet' skill (live data) won't work until you add FLEET_API_KEY to .env."

# Anthropic key (optional: leave blank to log in with a Pro/Max subscription instead).
if [ -z "${ANTHROPIC_API_KEY:-}" ]; then
  read -r -p "Anthropic API key (blank = use a Claude subscription via 'claude' login): " ANTHROPIC_API_KEY || true
fi

# Central Skills Gateway key (optional — only for browsing the shared catalog read-only).
GATEWAY_VALUE="${SAASLABS_SKILLS_API_KEY:-}"
if [ -z "$GATEWAY_VALUE" ] || [ "$GATEWAY_VALUE" = "Bearer" ]; then
  read -r -p "Central skills gateway token (optional, Enter to skip): " RAW_KEY || true
  [ -n "${RAW_KEY:-}" ] && GATEWAY_VALUE="Bearer ${RAW_KEY}" || GATEWAY_VALUE=""
fi

# --- write .env ------------------------------------------------------------
# Values are quoted so spaces (e.g. "Bearer <token>") survive `. ./.env` sourcing.
cat > .env <<EOF
ANTHROPIC_API_KEY="${ANTHROPIC_API_KEY:-}"
FLEET_API_KEY="${FLEET_API_KEY:-}"
AGENT_BASE_URL="${AGENT_BASE_URL}"
SAASLABS_SKILLS_API_KEY="${GATEWAY_VALUE}"
POD="${POD}"
EOF
ok "Wrote .env"

# --- render .mcp.json (central read-only gateway) --------------------------
# Only wire the gateway if a token was provided; otherwise skip (the fleet skill
# is the primary surface and needs no MCP server).
if [ -n "$GATEWAY_VALUE" ]; then
  template="$(cat .mcp.json.template)"
  printf '%s\n' "${template/Bearer __PASTE_YOUR_GATEWAY_KEY__/$GATEWAY_VALUE}" > .mcp.json
  ok "Wrote .mcp.json (central skills gateway, read-only)"
else
  rm -f .mcp.json
  warn "No gateway token — skipped .mcp.json (central-skill browsing disabled; the live 'fleet' agent still works)."
fi

# --- render CLAUDE.md from template + pod persona --------------------------
# Literal (non-regex) substitution via bash parameter expansion, so titles
# containing '&' (e.g. "Analytics & Data") aren't mangled the way sed would.
PERSONA_FILE="pods/${POD}.md"
[ -f "$PERSONA_FILE" ] || { echo "Missing $PERSONA_FILE"; exit 1; }
content="$(cat CLAUDE.md.template)"
persona="$(cat "$PERSONA_FILE")"
content="${content//\{\{POD_TITLE\}\}/$POD_TITLE}"
content="${content//\{\{POD_DOMAIN\}\}/$POD_DOMAIN}"
content="${content//\{\{POD_PERSONA\}\}/$persona}"
content="${content//\{\{POD\}\}/$POD}"
printf '%s\n' "$content" > CLAUDE.md
ok "Wrote CLAUDE.md ($POD persona)"

# --- ensure the personal-skills dir is a REAL directory --------------------
# Claude Code auto-discovers .claude/skills/<name>/SKILL.md and hot-reloads new
# subfolders as long as .claude/skills/ exists at launch. (No symlink — symlinked
# skill dirs are unreliable across platforms.)
if [ -L .claude/skills ]; then
  rm -f .claude/skills
  warn "Removed a legacy .claude/skills symlink (now using a real directory)."
fi
mkdir -p .claude/skills
chmod +x ./fleet-query.sh ./new-skill.sh 2>/dev/null || true
ok "Personal skills directory ready: .claude/skills/ (bundled: fleet, new-skill, hello-local)"

# --- verify reachability (non-fatal) ---------------------------------------
command -v python3 >/dev/null 2>&1 || warn "python3 not found — the 'fleet' skill needs it for safe JSON. Install Python 3."
if command -v curl >/dev/null 2>&1; then
  # The /query endpoint should answer 401 without a body — that means it's up and auth-guarded.
  CODE="$(curl -sS -o /dev/null -w '%{http_code}' --max-time 10 -X POST "${AGENT_BASE_URL}/query" -H 'Content-Type: application/json' -d '{}' 2>/dev/null)" || true
  CODE="${CODE:-000}"
  case "$CODE" in
    401|400|422) ok "Agent endpoint reachable ($AGENT_BASE_URL → HTTP $CODE)" ;;
    200) ok "Agent endpoint reachable (HTTP 200)" ;;
    000) warn "Could not reach $AGENT_BASE_URL — check the URL / network / VPN." ;;
    404) warn "Got 404 from $AGENT_BASE_URL/query — double-check the base URL (admin 'HTTP & API' tab)." ;;
    *)   warn "Agent endpoint returned HTTP $CODE — verify the base URL and your key." ;;
  esac
  if [ -n "$GATEWAY_VALUE" ]; then
    curl -fsS --max-time 10 "$GATEWAY_HEALTH" >/dev/null 2>&1 && ok "Skills gateway reachable" || warn "Could not reach the skills gateway health endpoint (non-fatal)."
  fi
fi
command -v node >/dev/null 2>&1 || { [ -n "$GATEWAY_VALUE" ] && warn "Node.js not found — needed only for central-skill browsing via 'npx mcp-remote'."; }

say ""
say "Setup complete. Next:"
say "  1) cd $HERE"
say "  2) claude"
say "  3) Try a live-data question:   what was MRR last month?"
say "     (the agent uses the 'fleet' skill → your personal key → real BigQuery/HubSpot)"
say "  4) Make your own skill:         say \"create a skill that …\"   or   ./new-skill.sh \"My Skill\""
