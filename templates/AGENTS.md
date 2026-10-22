# AGENTS.md — {{PROJECT NAME}}

> Master contract for this repository. One source of truth for what this project
> is, how it is worked, and what is never allowed. If anything here conflicts with
> an instruction in chat, this file wins.
>
> **Universal rules:** the factory standard section below is synced from
> `atakumi-global/factory-standards` and applies to every project. The project
> sections after it add specifics, never contradict it.

<!-- factory-standards:begin -->
<!-- The shared factory section is inserted here by sync_agents_md.py / factory-ci. -->
<!-- factory-standards:end -->

## What this is

{{One paragraph: the product, who it is for, and the problem it solves.}}

- **Repo:** {{remote URL or "local only"}}
- **Plane project:** {{identifier, e.g. PROJ}} — see `.plane.json`
- **Owner / approver:** {{name / email}}
- **Agent account:** {{agent member email}}
- **Data policy:** `{{zdr | standard}}` — see `factory-config`
- **Knowledge base:** {{https://github.com/ORG/kb-COMPANY-PROJECT}}

## Stack

| Area | Tech |
| --- | --- |
| Language | {{…}} |
| Framework | {{…}} |
| Database | {{…}} |
| Testing | {{…}} |
| Package manager | {{…}} |
| Deploy | {{…}} |

## Layout

```
{{src/…}}      source
docs/          durable docs (architecture, deployment, runbook, security)
design-system/ DESIGN.md and brand assets
prototypes/    static HTML prototypes, one folder per work item and version
project/       discovery inputs: briefs, plans, intake
```

## Plane — this project

The Plane rules (lifecycle, estimates, approval, pickup, links) are in the factory
standard section above. Project specifics:

- **Workspace / project:** `{{workspace}}` / `{{IDENTIFIER}}` — ids in `.plane.json`.
- **Issue list:** `https://plane.atakumi.net/{{workspace}}/projects/{{project-uuid}}/issues/`
- **Labels in use:** {{feature, bug, chore, spike, ...}}

## Design

- All UI is designed before it is built. A **design outcome** (new or changed UI,
  layout, styling, user-visible copy, interaction, email/PDF template) stops for
  design approval.
- Designs are versioned records: `prototypes/<work-item-id>/v1`, `v2`, …
  Never overwrite a previous version.
- `design-system/DESIGN.md` is the binding visual contract, with the verifier
  command that checks it. Run the verifier before calling UI work done.

## Conventions

- {{Package manager and why; import paths; where server/client code lives.}}
- Logging via {{logger}}; never `console.log` in application code.
- Comments only where they earn their place; code should be self-documenting.
- Commit style: Conventional Commits — `feat:`, `fix:`, `docs:`, `chore:`,
  `refactor:`, `test:`, `perf:`, `ci:`. One focused commit per task, referencing
  the work-item identifier.

## Done-gates

Run these before claiming anything is done, and paste the result as evidence:

```bash
{{install}}
{{lint}}
{{typecheck}}
{{test}}
{{build}}
{{verify:brand / design verifier, if UI}}
```

## Commands

```bash
{{dev}}       start local stack
{{build}}     production build
{{test}}      tests
```

**Local stack rule:** all start/stop/restart goes through {{script, e.g.
stack.ps1}} on the owner's laptop and `./stack.sh` in a server sandbox. Never
hand-spawn dev servers.

## Branch flow and exceptions

- Branch flow: `feat/<item-id>-<slug>` → `dev` → `stage` → `{{main | prod}}`.
- Deploy triggers: {{what deploys what, e.g. "Coolify deploys stage from `stage`"}}.
- Exceptions to `WORKFLOW.md`: {{none | protected dev / auto-deploying branch / ...}}.

## Hard-won invariants — do not break

1. {{Invariant 1 — the thing that cost real pain when broken.}}
2. {{Invariant 2.}}

## Security

- **Never commit secrets.** No keys in code, config, comments, or this file.
  Environment variables only; `.env*` and `opencode.json` are gitignored.
- Validate and allowlist input before it reaches a database or a prompt.
- Check authentication and authorisation at the API boundary, not only in the UI.

## Known issues

1. {{Issue, with enough context that the next person does not rediscover it.}}

## Handover

`HANDOVER.md` carries current state, battle scars, verified facts and next
actions. Update it whenever state changes. It is what the next agent or person
reads first after this file.
