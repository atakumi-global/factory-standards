# Knowledge base convention

Each project has a private knowledge-base repository named `kb-<company>-<project>`
(for example `kb-atak-airtime`), in the GitHub organisation that holds the project's
code. The organisation for each project is recorded in the private project registry
(`factory-config`).

`atakumi-global/kb-global` holds cross-project knowledge. Agents read it; only the
factory owner writes to it.

One repository per project (not one folder per project in a shared repository) is
deliberate: GitHub cannot restrict access to part of a repository, so separate
repositories are what keep one project's agents out of another project's knowledge.

## What goes where

| Kind of information | Home |
| --- | --- |
| Live state of work | Plane |
| Current build state, battle scars, verified facts, next actions | `HANDOVER.md` in the code repository |
| Durable docs a maintainer needs (architecture, deployment, runbook) | `docs/` in the code repository |
| Decisions, conventions, gotchas, terminology, session learnings | `kb-<company>-<project>` |
| Knowledge that applies across projects | `kb-global` |

## Layout

Copy `template/` to start a new knowledge base.

```
README.md          what the project is, client, stack, links
architecture.md    how the system fits together (summary; detail stays in docs/)
conventions.md     how this codebase does things
glossary.md        client terminology
gotchas.md         traps, flaky tests, environment quirks
decisions/         one file per decision: YYYY-MM-DD-<slug>.md
log/               one file per agent session: YYYY-MM-DD-<ITEM-ID>.md
```

One file per decision and per session keeps parallel agents from conflicting.

## Rules

- Durable knowledge only.
- Every fact cites its source: work-item link, commit or file path.
- Update an existing entry instead of adding a near-duplicate.
- Never store secrets, credentials, personal information or client data.
- A decision that is reversed is not deleted: mark it `Status: superseded by <file>`.

## Reading it

Clone the knowledge-base repositories into one folder and open that folder in
Tolaria (or any Markdown editor). GitHub's web view works on a phone.
