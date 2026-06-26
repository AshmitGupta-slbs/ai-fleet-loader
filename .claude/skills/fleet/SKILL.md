---
name: fleet
description: Ask the live company fleet agent for anything that needs REAL data or fleet capabilities — BigQuery metrics, HubSpot CRM, revenue/MRR, signups, funnels, reporting, or any question only the production agent can answer. Use whenever the task needs actual company data rather than a local-machine action.
---

# Fleet — bridge to the live, data-capable agent

This project runs on your machine, but your machine does **not** have the company's data
credentials (BigQuery, HubSpot, etc.) — and it shouldn't. Instead, your **personal API key**
gives you access to the **deployed fleet agent**, which has all of those tools server-side.
This skill is how you reach it.

## When to use
Use this whenever a request needs **real company data or a fleet capability**, e.g.:
- "what was MRR last month?", "signups last week", "break that down by plan"
- HubSpot CRM lookups, funnels, dashboards, reporting
- anything the Slack agents can answer that depends on live data

Do **not** use it for local-machine tasks (reading/editing files, running commands here) — do
those directly with your normal tools and personal skills.

## How to call it
Run the bundled helper from the project root. It reads `AGENT_BASE_URL` and `FLEET_API_KEY`
from `.env`, POSTs to the deployed agent, and prints the answer:

```bash
./fleet-query.sh "what was MRR last month?"
```

- The **answer** is printed on stdout — relay it to the user.
- A line `FLEET_SESSION_ID=<id>` is printed on **stderr**. For a **follow-up** in the same
  conversation, pass that id back as the second argument so the agent keeps context:

```bash
./fleet-query.sh "now break that down by plan" <FLEET_SESSION_ID>
```

Keep reusing the same session id for the rest of a multi-turn investigation.

## Combine with personal skills
A personal skill can *describe* a workflow and use this skill for the data step. Example: a
"weekly revenue digest" personal skill asks the fleet for the numbers via `./fleet-query.sh`,
then you format/save them locally however the user wants.

## Errors
The helper gives a clear message and a non-zero exit on failure:
- **401** — your key is missing/invalid → ask the admin for a new key (admin **People & Keys →
  New key**) and re-run `./setup.sh`.
- **403** — you're not on this agent's allow-list → ask the admin to add you.
- **Could not reach** — check `AGENT_BASE_URL`, network, or VPN.

Never print or log the value of `FLEET_API_KEY`.
