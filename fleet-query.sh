#!/usr/bin/env bash
# Ask the deployed fleet agent a question and print its answer.
#
# This is the bridge to the REAL, data-capable agent (BigQuery / HubSpot / all
# fleet tools). It authenticates with your personal API key and runs server-side
# — no shared org credentials ever live on this machine.
#
# Usage:
#   ./fleet-query.sh "what was MRR last month?"            # new conversation
#   ./fleet-query.sh "break that down by plan" <session>   # continue a conversation
#
# Output:
#   - stdout: the agent's answer text
#   - stderr: a line "FLEET_SESSION_ID=<id>" — pass it back as arg 2 for multi-turn
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# Load .env (AGENT_BASE_URL, FLEET_API_KEY, POD, ...). Never printed.
[ -f "$HERE/.env" ] && set -a && . "$HERE/.env" && set +a || true

MSG="${1:-}"
SESSION="${2:-}"
if [ -z "$MSG" ]; then
  echo "usage: ./fleet-query.sh \"your question\" [session_id]" >&2
  exit 2
fi
: "${AGENT_BASE_URL:?AGENT_BASE_URL is not set — run ./setup.sh}"
: "${FLEET_API_KEY:?FLEET_API_KEY is not set — run ./setup.sh}"
command -v python3 >/dev/null 2>&1 || { echo "python3 is required (for safe JSON encoding)." >&2; exit 3; }

# Build the JSON body safely (handles quotes/newlines in the message).
PAYLOAD="$(MSG="$MSG" SESSION="$SESSION" python3 - <<'PY'
import json, os
body = {"message": os.environ["MSG"]}
sid = os.environ.get("SESSION", "").strip()
if sid:
    body["session_id"] = sid
print(json.dumps(body))
PY
)"

# POST /query. Append the HTTP status as a trailing line so we can branch on it.
# `|| true` so a connection failure (curl exit!=0) doesn't abort under `set -e` —
# we want our own friendly error below to run instead.
RAW="$(curl -sS -X POST "${AGENT_BASE_URL%/}/query" \
  -H "Authorization: Bearer ${FLEET_API_KEY}" \
  -H "Content-Type: application/json" \
  -d "$PAYLOAD" \
  -w $'\n%{http_code}' 2>/dev/null)" || true
CODE="$(printf '%s' "$RAW" | tail -n1)"
[ -z "$CODE" ] && CODE=000
BODY="$(printf '%s' "$RAW" | sed '$d')"

if [ "$CODE" != "200" ]; then
  case "$CODE" in
    401) echo "ERROR 401: your FLEET_API_KEY is missing or invalid. Ask the admin for a new key (People & Keys → New key) and re-run ./setup.sh." >&2 ;;
    403) echo "ERROR 403: your account isn't on this agent's allow-list. Ask the admin to add you (People & Keys)." >&2 ;;
    000) echo "ERROR: could not reach $AGENT_BASE_URL. Check the URL / your network / VPN." >&2 ;;
    *)   echo "ERROR: fleet agent returned HTTP $CODE." >&2 ;;
  esac
  printf '%s\n' "$BODY" >&2
  exit 1
fi

# Print the answer on stdout; echo the session id to stderr for reuse.
printf '%s' "$BODY" | python3 -c '
import sys, json
try:
    d = json.load(sys.stdin)
except Exception:
    sys.stderr.write("Could not parse agent response as JSON.\n"); sys.exit(1)
sys.stdout.write(d.get("response", ""))
sys.stdout.write("\n")
sys.stderr.write("FLEET_SESSION_ID=%s\n" % (d.get("session_id", "") or ""))
if d.get("pod_used"):
    sys.stderr.write("pod_used=%s\n" % d["pod_used"])
'
