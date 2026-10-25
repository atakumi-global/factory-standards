# Changelog

Versions follow semantic versioning: MAJOR removes or redefines a rule, MINOR adds
one, PATCH clarifies.

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
