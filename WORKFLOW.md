# WORKFLOW.md — repository workflow (canonical)

> The single source of truth for how work lands in every repository built to the
> factory standard. The shared section of each `AGENTS.md` links here; project
> `AGENTS.md` files may add specifics but must not contradict this document. Where a
> repository's reality differs, the deviation is recorded in that repository's
> `AGENTS.md` (and in the private exceptions register in `factory-ops`).

## Principles

1. All work happens on a **feature branch** named with the work-item id. Protected
   branches (`main`, `stage`, `prod`, `master`) are never committed to directly.
2. **No PRs.** The feature branch is merged into local `dev`; promotion to stage and
   production is a manual GitHub action.
3. Local `dev` is the integration branch. `origin/dev` is the shared one — other
   agents' work reaches you only through it.
4. Never force-push; never rewrite published history.
5. Gates **and `factory-check`** run **after** `dev` is merged into the feature, on the
   exact tree that then lands. Nothing reaches `dev` without both passing.
6. CI re-runs the security scans and gates on every push to `dev`. A red `dev` blocks
   promotion.
7. The agent never approves and never promotes; Plane items stop at **In Review**.
   Production promotion requires the owner's approval in the GitHub `prod`
   environment.

## The finish sequence

Run from the project repository, on the feature branch (`feat/<ITEM-ID>-slug`).

```bash
git fetch origin
git checkout dev
git pull --ff-only origin dev           # 1. catch other agents' work first
git checkout feat/<ITEM-ID>-slug
git merge dev                           # 2. integrate dev into the feature
#    resolve conflicts, then run the project's gates (lint, typecheck, test, build)
factory-check                           #    and the security scans
git checkout dev
git merge --no-ff feat/<ITEM-ID>-slug   # 3. merge message references the item id
git push origin dev                     # 4. publish dev
```

5. Restart the local environment with `./stack.sh restart` (see `STACK.md`) — never
   hand-spawn servers. On the agent server skip this (`finish-work --no-restart`): a dev
   preview that is in use restarts from `dev` by itself within about two minutes, and
   one that is not starts on the latest `dev` when someone opens it.
6. In GitHub: promote `dev` → stage (manual), then stage → production (manual,
   approved in the `prod` environment). Promotion is never done locally and
   never by an agent.
7. Record it in Plane: comment the branch, merge commit, gate and `factory-check`
   evidence, security checklist outcome and pushed state; move the item to
   **In Review** and assign the owner.

If `origin/dev` moves between step 2 and step 4: merge `dev` into the feature again,
re-run the gates and `factory-check`, push again. Never force-push.

## Divergence and conflicts

- Conflict during `git merge dev` on the feature: resolve on the feature branch,
  re-run the gates, continue.
- `git pull --ff-only` fails (local dev diverged): stop. Inspect with
  `git log --oneline dev...origin/dev` and reconcile deliberately — never force-push.
- Push rejected (`non-fast-forward`): pull/re-merge, re-gate, retry.
- Anything unexpected: stop and report; do not invent a workaround.

## Exceptions

Common deviations, each recorded in the affected repository's `AGENTS.md`:

| Kind | Rule |
| --- | --- |
| `dev` is protected and PR-based | Finish the feature locally, push the branch, open the PR; the human merges. |
| Hosting auto-deploys every branch, or `dev` | Treat a push as a deployment. |
| Single-branch repositories (`main` only, e.g. GitHub Pages) | Work on a branch; `main` is merged and pushed only on the owner's explicit instruction. |
| Scheduled jobs commit to the default branch | Avoid merging during the job's run window. |
| Fork with an upstream remote | Never push the upstream; push to the organisation's fork. |

## Automation

- `scripts/finish-work.ps1` (owner's laptop, Windows) and `scripts/finish-work.sh`
  (server sandboxes, Linux/macOS) perform steps 1–5 mechanically, with guards:
  feature branch with a work-item id, clean tree, protected-branch refusal, gate
  command required, `factory-check` required, no force-push ever.
- Agents with command support may wrap it (for example a `/finish-work` command): it
  re-retrieves the Plane item, runs the script with the repository's gates, then
  comments evidence and sets **In Review**.
