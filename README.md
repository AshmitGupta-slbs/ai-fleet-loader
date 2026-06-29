# Run a fleet agent locally — with full data access and your own skills

Use one of the fleet agents (**Dwight, Jim, Toby, Ryan, Pam**) **on your own machine** through
**Claude Code**. Your **personal API key** gives you the *real* agent — live BigQuery, HubSpot, and
every other fleet tool, run securely server-side — and you can add your **own custom skills** locally,
in seconds, without ever touching the shared library.

## Install (one command)

On macOS or Linux (Windows: use WSL):

```bash
curl -fsSL https://raw.githubusercontent.com/AshmitGupta-slbs/ai-fleet-loader/main/install.sh | bash
```

That installs the prerequisites (Node + Claude Code), downloads this kit to `~/ai-fleet-loader`, and runs
setup — which asks for your **pod**, your **personal API key**, and your **agent URL**. Then:

```bash
cd ~/ai-fleet-loader && claude
```

> Already have the kit cloned? Just run `./setup.sh` inside it, then `claude`.

**Where do the keys come from?** Ask your fleet admin. In the agent's admin panel,
**People & Keys → "New key"** issues *your* personal key; the **"HTTP & API"** tab shows your agent's
base URL. (You optionally also get a read-only *skills gateway* token to browse the shared catalog.)

## How it works — three surfaces

```
~/ai-fleet-loader/
  .claude/skills/   YOUR personal skills (real folder, auto-discovered + hot-reloaded)
    fleet/          → bundled: bridge to the LIVE agent (real data) via your key
    new-skill/      → bundled: "create a skill that…" writes a new skill for you
    hello-local/    → sample local-machine skill
    kremlin-wall/   → bundled: always-on ingestion defense (see the Security section in CLAUDE.md)
  .env              your keys + agent URL (never commit this)
  CLAUDE.md         your pod's persona + the rules the agent follows
  fleet-query.sh    the helper the `fleet` skill calls (POST /query with your key)
  new-skill.sh      scaffolder: ./new-skill.sh "My Skill"
```

1. **Live data → the `fleet` skill.** Ask a real question and the agent calls the deployed fleet agent
   with your key; BigQuery/HubSpot/etc. run server-side and the answer comes back. No company
   credentials ever live on your laptop.
2. **Personal skills → `.claude/skills/`.** Yours alone, local, hot-reloaded. They win over central
   skills on a name clash.
3. **Central skills → the read-only gateway** (optional). The shared playbooks, fetched on request,
   never modifiable from here.

## Try it

In `claude`, ask:

- **"What was MRR last month?"** → the agent uses the `fleet` skill → your key → real data → answer.
- **"What personal skills do I have?"** → it lists `fleet`, `new-skill`, `hello-local`.
- **"Summarize this file: ./README.md"** → `hello-local` reads a local file (a task on *your* machine).

## Add your own skill — three easy ways

1. **Just ask the agent** (easiest): *"create a skill that drafts a standup from my git log."* The
   bundled **new-skill** skill writes `.claude/skills/standup/SKILL.md` for you — live immediately.
2. **Scaffold it:**
   ```bash
   ./new-skill.sh "Tidy Downloads"     # creates .claude/skills/tidy-downloads/SKILL.md
   $EDITOR .claude/skills/tidy-downloads/SKILL.md
   ```
3. **Copy + edit:** `cp -R .claude/skills/hello-local .claude/skills/my-skill` and edit its `SKILL.md`.

A skill is just a folder with a `SKILL.md`:

```markdown
---
name: Tidy Downloads
description: Sort files in my ~/Downloads into folders by type. Use when I say "tidy downloads".
---

# Tidy Downloads
1. List ~/Downloads.
2. Move files into Images/, Docs/, Archives/, Other/ by extension.
3. Report what moved.
```

New skills are picked up **without restarting** `claude`. If a skill needs real company data, have its
steps call the `fleet` skill (`./fleet-query.sh "…"`). Because this is the same format as the central
library, a useful personal skill can later be promoted to the shared repo via the Governance Portal —
no rewrite.

## What you can and can't do

- ✅ Ask real data questions — the agent has full BigQuery/HubSpot/etc. access via your key.
- ✅ Add and run your own personal skills; have the agent read/edit files and run commands locally.
- ✅ Browse the shared central skills read-only (if you configured the gateway token).
- ❌ You can't modify the central library from here (read-only by construction).
- ❌ Company data credentials never touch your machine — the live agent runs them server-side.

## Troubleshooting

| Symptom | Fix |
|---|---|
| `claude: command not found` | Re-open your terminal, or ensure npm's global bin is on PATH. Re-run `install.sh`. |
| Live-data questions fail with **401** | Your `FLEET_API_KEY` is wrong/rotated. Ask the admin for a new key (People & Keys → New key) and re-run `./setup.sh`. |
| **403** on live-data questions | You're not on the agent's allow-list. Ask the admin to add you. |
| "Could not reach …" / **404** | Check `AGENT_BASE_URL` in `.env` (the admin "HTTP & API" tab has the exact value). |
| `python3 is required` | Install Python 3 — the `fleet` helper uses it for safe JSON. |
| Personal skills not showing | Confirm `.claude/skills/<name>/SKILL.md` exists; a brand-new top-level `.claude/skills` needs a `claude` restart (setup.sh creates it for you). |
| Switch pods | Re-run `./setup.sh` and pick a different pod (one personal key per pod). |
| Central skills (gateway) errors | `npx mcp-remote` needs Node; the `SAASLABS_SKILLS_API_KEY` value must start with `Bearer `. This is optional — the live `fleet` agent works without it. |

## Safety

- Your `.env` holds your keys — it's git-ignored; don't commit or share it.
- The `fleet` skill sends your key only to your configured `AGENT_BASE_URL` and never prints it.
- The central library is read-only from here; nothing you do locally can change it.
