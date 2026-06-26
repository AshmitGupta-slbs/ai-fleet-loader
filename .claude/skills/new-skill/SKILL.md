---
name: new-skill
description: Create a new personal skill from a plain-English description. Use when the user says "create a skill", "make a skill that…", "add a skill for…", "teach yourself to…", or otherwise wants to capture a repeatable workflow they can reuse later.
---

# New Skill — author a personal skill from chat

Personal skills live in `.claude/skills/<name>/SKILL.md` in this project and are picked up
automatically (no restart needed, because `.claude/skills/` already exists). This skill lets the
user create one just by describing it — no manual file editing required.

## When to use
When the user wants to capture a reusable workflow, e.g. "create a skill that drafts a standup
from my git log", "make a skill to tidy my Downloads folder", "add a skill for our PR checklist".

## What to do
1. **Gather the essentials** (ask only for what's missing — infer the rest from their description):
   - a short **name** (you'll convert it to `kebab-case` for the folder),
   - **when to use it** (the trigger phrases / situations),
   - the **steps** the skill should follow.
2. **Pick the folder name**: lowercase, words joined by hyphens (e.g. "Tidy Downloads" → `tidy-downloads`).
   If `.claude/skills/<name>/` already exists, confirm before overwriting.
3. **Write** `.claude/skills/<name>/SKILL.md` using the **Write** tool with this exact shape:

   ```markdown
   ---
   name: <Human Readable Name>
   description: <one sentence: what it does + when to use it, including trigger phrases>
   ---

   # <Human Readable Name>

   ## When to use
   <the situations / phrases that should trigger this skill>

   ## What to do
   1. <step>
   2. <step>
   3. <step>
   ```

   - The `description` is what makes the skill auto-trigger later — make it specific and include
     the words the user would actually say.
   - If the workflow needs **live company data**, have the steps call the **`fleet`** skill
     (`./fleet-query.sh "…"`) for that part; do local actions directly.
4. **Confirm**: tell the user the skill is saved at `.claude/skills/<name>/SKILL.md` and is live
   immediately — they can invoke it now by describing the task or with `/<name>`.

## Notes
- This format is identical to the central fleet skill format, so a useful personal skill can later
  be promoted to the shared library via the Governance Portal — no rewrite.
- Prefer small, single-purpose skills with clear trigger descriptions.
