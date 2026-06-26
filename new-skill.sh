#!/usr/bin/env bash
# Scaffold a new personal skill.
#
# Usage:  ./new-skill.sh "My Skill Name"
# Creates .claude/skills/<my-skill-name>/SKILL.md from a template, ready to edit.
# It's picked up live by a running `claude` session (no restart needed), because
# .claude/skills/ already exists.
#
# (You can also just tell the agent "create a skill that …" — the bundled
#  `new-skill` skill writes it for you. This script is the manual path.)
set -euo pipefail

HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

RAW_NAME="${*:-}"
if [ -z "$RAW_NAME" ]; then
  echo "usage: ./new-skill.sh \"My Skill Name\"" >&2
  exit 2
fi

# kebab-case: lowercase, non-alnum -> '-', collapse/trim dashes.
SLUG="$(printf '%s' "$RAW_NAME" \
  | tr '[:upper:]' '[:lower:]' \
  | sed -E 's/[^a-z0-9]+/-/g; s/^-+//; s/-+$//')"
if [ -z "$SLUG" ]; then
  echo "Could not derive a folder name from \"$RAW_NAME\"." >&2
  exit 2
fi

DIR="$HERE/.claude/skills/$SLUG"
SKILL="$DIR/SKILL.md"
if [ -e "$SKILL" ]; then
  echo "✗ $SKILL already exists — pick a different name or edit it directly." >&2
  exit 1
fi

mkdir -p "$DIR"
cat > "$SKILL" <<EOF
---
name: $RAW_NAME
description: TODO one sentence — what this does AND when to use it (include the words you'd actually say to trigger it).
---

# $RAW_NAME

## When to use
TODO — the situations / phrases that should trigger this skill.

## What to do
1. TODO first step.
2. TODO next step.
3. TODO — if you need live company data (BigQuery / HubSpot / metrics), call the
   \`fleet\` skill:  ./fleet-query.sh "your question"
EOF

echo "✓ Created $SKILL"
echo "  Edit it, then just describe the task in \`claude\` (or run /$SLUG) — it's live now, no restart needed."
