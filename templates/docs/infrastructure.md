# High-performance infrastructure — {{PROJECT NAME}}

How this site is hosted and served to visitors: origins, the Bunny pull zone, DNS,
SSL, caching and the checks that prove it. The rule is
`factory-standards/HOSTING.md`; this file holds this site's own values and evidence.

**Status:** {{applied on stage / applied in production / not started}}
**Last checked:** {{YYYY-MM-DD}}
**Owner of the live settings:** the factory owner (agents cannot change Bunny or
Coolify).

## Hostnames

| Environment | Public hostname | Origin hostname | Coolify app |
| --- | --- | --- | --- |
| stage | `{{stage.example.com}}` | `{{origin-stage.example.com}}` | `{{app name}}` |
| production | `{{www.example.com}}` | `{{origin.example.com}}` | `{{app name}}` |

Both hostnames (origin and public) are on the Coolify app, added one at a time.
`{{https://stage.example.com}}` is the public site for stage;
`{{https://www.example.com}}` is production.

## DNS and SSL

| Record | Type | Target | Proxy |
| --- | --- | --- | --- |
| `{{origin-stage.example.com}}` | A | `{{Coolify server IP}}` | DNS only (grey cloud) |
| `{{stage.example.com}}` | CNAME | `{{pull-zone-hostname}}` | DNS only (grey cloud) |
| `{{origin.example.com}}` | A | `{{Coolify server IP}}` | DNS only (grey cloud) |
| `{{www.example.com}}` | CNAME | `{{pull-zone-hostname}}` | DNS only (grey cloud) |

SSL is issued and verified in Bunny for each public hostname. The origin is served
over `https://` only.

## Bunny pull zone

| Setting | Value |
| --- | --- |
| Pull zone | `{{pull-zone-name}}` |
| Origin URL | `https://{{origin-stage.example.com}}` (stage), `https://{{origin.example.com}}` (production) |
| Forward Host Header | on |
| Vary Cache | URL Query String ticked |
| Edge rule | **No cache for admin, API and logged in**: Override Cache Time `0`, match any |
| Edge rule matches | Request URL `*/admin*`, Request URL `*/api/*`, Cookie Value `payload-token` = `*`, Cookie Value `__prerender_bypass` = `*` |
| `Critical-CH` header | absent (removed from the app) |

Add the site's own login cookie to the edge rule when it is not Payload's
`payload-token`, and add every private path (for example `*/account*`,
`*/dashboard*`) to the Request URL matches.

## Checks

Run from any machine with `curl` (`curl.exe` on Windows). Paste the date and the
result when each environment is applied.

| Check | Command | Expected | Stage | Production |
| --- | --- | --- | --- | --- |
| No client-hint reload loop | `curl -sI https://{{stage.example.com}}` | no `critical-ch` header | {{}} | {{}} |
| Cached public page | the same command twice | second response `CDN-Cache: HIT` | {{}} | {{}} |
| Admin is not cached | `curl -sI https://{{stage.example.com}}/admin` | `CDN-Cache: BYPASS` | {{}} | {{}} |
| API is not cached | `curl -sI https://{{stage.example.com}}/api/health` | `CDN-Cache: BYPASS` | {{}} | {{}} |
| Logged-in user is not cached | `curl -sI -H "Cookie: payload-token=check" https://{{stage.example.com}}/` | `CDN-Cache: BYPASS` | {{}} | {{}} |
| Data requests have their own entry | `curl -sI "https://{{stage.example.com}}/?_rsc=check"` twice | second response `CDN-Cache: HIT`, not the HTML page | {{}} | {{}} |
| No reload | open the site in a new incognito window | it loads once | {{}} | {{}} |

## Performance choices

- Fonts and other static assets are self-hosted or served from the site's own
  origin; no third-party CDN in production (see `design-system/DESIGN.md`).
- Public pages are cacheable at the edge; anything personalised is excluded by the
  edge rule, not by turning caching off for the whole site.
- Images and build output live in the repository's normal pipeline so a redeploy
  does not depend on a manual upload.

## Open items

- {{What is still not applied or not verified, and who does it.}}

## Change log

| Date | Change | By |
| --- | --- | --- |
| {{YYYY-MM-DD}} | {{what changed in hosting, DNS, caching or the checks}} | {{name}} |
