---
name: hello-local
description: Demo personal skill — summarize a local file on the user's machine. Use to test that personal skills load and local-machine tasks run. Triggers on "hello local", "summarize this file", "test my local skill setup".
---

# Hello Local

This is a **personal** skill living in `.claude/skills/`. It proves three things end-to-end:
1. Claude Code auto-discovered a skill from this project's `.claude/skills/` folder.
2. The skill can drive a **task on the user's own machine** (reading local files).
3. None of this touches the central skill library or needs the live fleet agent.

## When to use
When the user says "hello local", "summarize this file", or "test my local skill setup".

## What to do
1. Ask which file to summarize, or use the path they gave. Default to `./README.md` if they don't specify.
2. Read the file from the local filesystem (use the Read tool).
3. Produce a 3–5 bullet summary: what the file is, its key points, anything notable.
4. Confirm: "✅ Local skill loaded from `.claude/skills/` and ran a task on your machine — no central library or live data touched."

## Notes
- This is a template. To make your own: say "create a skill that …" (the **new-skill** skill writes
  it for you), or run `./new-skill.sh "My Skill"`, or copy this folder and edit `SKILL.md`.
- For workflows that need **real company data**, use the **fleet** skill (`./fleet-query.sh`) for the
  data step — this hello-local demo intentionally stays fully local.
