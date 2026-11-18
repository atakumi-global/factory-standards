# Changelog

Versions follow semantic versioning: MAJOR removes or redefines a rule, MINOR adds
one, PATCH clarifies.

## 3.1.0 - 2026-11-19

- Public sites behind Bunny CDN follow one hosting standard: an HTTPS origin with its
  own `origin-<environment>` hostname, Forward Host Header, both hostnames on the
  Coolify app, Vary Cache by URL Query String, and the edge rule "No cache for admin,
  API and logged in" (Override Cache Time 0; `*/admin*`, `*/api/*`, cookie
  `payload-token` and `__prerender_bypass`). No `Critical-CH` header. New rule in
  `HOSTING.md`; each project records its own values in `docs/infrastructure.md`,
  scaffolded from `templates/docs/infrastructure.md` (INTFACTORY-42).

## 3.0.0 - 2026-11-18

- The standard is delivered by the agent runtime, not copied into repositories (owner,
  2026-11-18). `/opt/factory/standards/agents/AGENTS.shared.md` is loaded as opencode's
  global rules through a symlink the `opencode` wrapper creates at
  `~/.config/opencode/AGENTS.md`; the owner's laptop loads `ALL_AGENTS.md` the same way.
  A repository's `AGENTS.md` adds project specifics only. A section between
  `factory-standards:begin` and `factory-standards:end` is an old snapshot: it is
  ignored, and `scripts/sync_agents_md.py` deletes it. A standard release now needs one
  install on the agent server and no commit in any repository, so the per-repository
  sync and its version drift check are gone (`agents/AGENTS.shared.md`, `README.md`,
  `scripts/sync_agents_md.py`, `templates/AGENTS.md`, `factory-ci` standard-drift,
  `factory-ops` setup-project and install-factory-shared.sh).

## 2.2.0 - 2026-11-18

- Every action an agent describes names the machine or system, the full path or full URL,
  and the exact command or clicks (owner, 2026-11-18). A step without all three is
  incomplete (`agents/AGENTS.shared.md`, Communication).

## 2.1.0 - 2026-11-18

- A Blocked item comes back by itself when the owner answers (owner, 2026-11-18). The
  broker keeps the agent assigned and adds the owner, marks the item `answered` when the
  newest comment is a person's, refuses In Progress until then, and reassigns it to the
  agent when it resumes. It also refuses Blocked until the factory has commented the
  question, so an older answer cannot count. The owner no longer moves answered items
  back to Todo (`agents/AGENTS.shared.md`, `agents/lead.md`, `agents/worker.md`).

## 2.0.0 - 2026-11-18

- A dependency is no longer the Blocked state (owner, 2026-11-18). An item whose
  description or a comment says `Depends on: <ITEM-ID>` stays in Todo until every
  dependency is Approved or later; the broker refuses to set it In Progress before that,
  and the next scheduled run picks it up by itself, so the owner approves once instead of
  moving the item back from Blocked. Blocked is now only for a human's answer or action
  (`agents/AGENTS.shared.md`, `agents/lead.md`, `agents/worker.md`).

## 1.2.0 - 2026-11-16

- End-of-run reports are two layers and terse: an **Activity log** (short bullets: what,
  where, result; no module-by-module detail and no restating the diff) and a **Manager
  summary** (plain language and short: what happened, decisions, blockers, what a human
  must do). Gate and `factory-check` evidence is one line on a pass
  (`### factory-check — pass`, scanners listed only when one fails), a human action names
  the action only (`* **Coolify redeploy after merge.**`) or, when it needs a code sample,
  where to run it, and repo state lists only repositories touched and leftovers
  (`Repo state: none changed.` when none; never temp files, tool artifacts or API
  payloads). Exact detail stays for failures, blockers and security findings
  (`agents/AGENTS.shared.md`, `agents/worker.md`, `agents/lead.md`).

## 1.1.0 - 2026-11-14

- Shared board: agents may comment on a person's item once it is In Progress or later
  (the broker allows it); moving it, reassigning it or changing its fields still needs
  its owner (`agents/AGENTS.shared.md`).

- Dev logins and seed data (STACK.md 8, 9): every instance seeds `<role>@factory.test` with
  the one factory dev password (`FACTORY_DEV_PASSWORD`, from Vaultwarden through
  setup-project), at least `admin`; tester's guides name that login and the Vaultwarden
  item, never the password. Seeds are realistic and built from the project's read-only
  data on the agent server (`/srv/factory-data/<PROJECT KEY>`), with real accounts
  replaced and personal data removed.

- Lead: during a run it reads the Todo queue again after every delivery, so items that
  arrive while it runs (sent back by a tester, for example) join the run; items sent back
  by a tester go before every non-urgent item; it finishes only on a fresh empty queue. The
  scheduled automation checks every 2 minutes (`agents/lead.md`).

- Dev baseline (standard procedure): findings already on `dev` that make `factory-check`
  or the gate fail are fixed by the factory first, as one urgent item "Dev fails
  factory-check" created by the lead; the worker that found them leaves its item In
  Progress, waiting for it, instead of setting it Blocked for the owner.

- Tester's guides name a working login (account, role, and the password or where it is
  written down for that environment), so anyone can test without asking; the lead checks
  it (`agents/worker.md`, `agents/lead.md`, `agents/AGENTS.shared.md`).

- `STACK.md`: the health URL proves the app is usable (its own database by instance
  name, migrations applied, a real query, required services), with a JSON body per
  check; compose services do not restart by themselves.

- A broken dev preview is the factory's own work: the preview watchdog reports it as an
  urgent Todo item "Dev preview does not start" (with the commits and logs); the lead
  dispatches it first, the worker fixes the cause in the code with a test.
- Database migrations are tested upgrading a database that already has data, not only an
  empty one (`agents/worker.md`).

- Shared board: agents work only on Plane items assigned to the agent account; people's
  items are read-only for agents (enforced by the broker on the agent server).

- Every item handed to a human (In Review) carries a tester's guide in Plane: `## How to
  test` with Where, Before you start, Steps, Expected, Not covered. Workers write it, the
  lead checks it, and the Plane broker refuses In Review without it.

- Ports on the agent server: the first half of a project's 20-port block is the dev
  preview's, the second half (`$FACTORY_TEST_PORTS`) is for agents' test databases and
  servers. Workers use only the second half and name containers after their item.

- Added: `agents/lead.md` and `agents/worker.md`. A lead developer agent reads the
  project's Todo queue from Plane, plans, and hands each item to a worker agent in its
  own Orca workspace; workers read their item from Plane themselves and stop at In Review.
- `agents/`: the lead reuses an item's earlier workspace (finished work whose merge was
  stopped) instead of starting over; workers continue from it and install dependencies
  first when `dev` changed them.
- `finish-work.sh`: works inside a git worktree whose `dev` is checked out elsewhere (Orca
  workspaces): merges on a detached HEAD at `origin/dev` and pushes `HEAD:dev`.

- Added: `STACK.md` and `templates/stack.sh`, one stack script contract for every
  project (`start|stop|restart|status|url|logs`, registry ports, loopback only,
  development secrets only). Agents on the agent server do not run the stack in
  their workspace; the dev preview follows `dev`.
- `stack.sh`: development secrets live in `~/.local/state/stack/`, outside the working
  tree (factory-check's working-tree scan no longer flags them); the app runs in its
  own process group so `stop` also ends watchers. Found by the first agent task
  (AIRTIME-92).

- `WORKFLOW.md`: GitHub environments are named `stage` and `prod`.
- Accepted dependency findings live in a root `osv-scanner.toml` (governed; each
  entry has a reason and a one-month expiry); `factory-check` uses it.

## 1.0.1 — 2026-10-25

- Added: agents commit with their own git identity, never the owner's, so
  `governed-files` can attribute changes to governed files.

## 1.0.0 — 2026-10-23

First release as `factory-standards`, built from Atakumi's existing internal agent standard.

Carried over unchanged in substance: the golden set, 12-state lifecycle, approval by
state, Fibonacci estimates in `estimate_point`, no-PR finish sequence, end-of-run
report, engineering discipline, design rules.

Changed:

- `ALL_AGENTS.md` becomes `agents/AGENTS.shared.md`, synced into every repository's
  `AGENTS.md` between markers, so the rules travel with the repository and work for
  agents that are not on the owner's laptop. Windows paths removed.
- Finish sequence: `factory-check` (secret, code, dependency, configuration scans)
  must pass on the merged tree before `dev`; CI rescans `dev`; production promotion
  is approved in the GitHub `production` environment.
- Templates: estimates aligned to 1–13 (the template still said 21); approval by
  state, not by a "recorded approval"; the README no longer mentions PRs.
- `finish-work.sh` added for Linux/macOS sandboxes alongside `finish-work.ps1`.

Added:

- Instructions come only from the task (prompt-injection rule).
- Security checklist per work item.
- Models and data policy (`zdr` / `standard`), gateway-only model access.
- Server sandbox rules (`.devcontainer/`, `./stack.sh`, egress allowlist).
- Knowledge-base convention (`kb-<company>-<project>`, `kb-global`).
- `CODEOWNERS` template for governed files.
- `sync_agents_md.py` with tests; `factory-check`.

Moved to private `factory-ops`: master brief, rollout tracker, hazards, per-repository
exceptions, port registry, Plane estimate migration tool.
