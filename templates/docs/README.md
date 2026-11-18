# docs/

Durable documentation. Anything a future maintainer needs that is not the code
and not a live ticket.

Suggested files as the project grows:

- `architecture.md` — how the system is put together and why.
- `infrastructure.md` — the high-performance hosting document: hostnames, origin,
  Bunny pull zone, DNS, SSL, caching and the checks. Copy it from the template and
  fill in the site's own values (rule: `factory-standards/HOSTING.md`).
- `deployment.md` — how to ship, environments, and the release path.
- `runbook.md` — operational procedures: restarts, backups, incidents.
- `security.md` — threat model, auth model, known controls.
- `manual.md` — the user or admin manual, if the product has one.

Work tracking does not live here. It lives in Plane.
