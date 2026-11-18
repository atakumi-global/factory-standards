# HOSTING.md — public site hosting behind Bunny CDN (canonical)

Every public factory website that sits behind a shared cache must follow this
standard. It records what a site behind Bunny needs so that Next.js data requests,
the admin, the API and logged-in users are served correctly. The owner applies the
live Bunny and Coolify settings; agents record and maintain the standard and each
project's document.

## What every site behind Bunny has

1. **An HTTPS origin, never HTTP.** The origin has its own hostname
   `origin-<environment>.<domain>` (for example `origin-stage.example.com`). Its DNS
   record points straight at the Coolify server (Cloudflare A record, **DNS only**,
   not proxied). The origin URL in the pull zone starts with `https://`.
2. **Forward Host Header on** in the Bunny pull zone, so the app sees the public
   hostname it is serving.
3. **Both hostnames on the Coolify app**: the origin hostname and the public
   hostname. Add them one at a time and wait for each to save.
4. **Caching, Vary Cache: URL Query String ticked.** The cache key then includes the
   query string, so Next.js data requests (`/?_rsc=...`) get their own cache entry
   instead of the cached HTML page.
5. **The edge rule "No cache for admin, API and logged in"**: Override Cache Time
   `0`, match **any** of:
   - Request URL `*/admin*`
   - Request URL `*/api/*`
   - Cookie Value `payload-token` = `*`
   - Cookie Value `__prerender_bypass` = `*`

   Name the auth cookie of the site's own framework in the project document; a site
   that is not Payload/Next.js adds its own login cookie alongside these matches.
6. **No `Critical-CH` header.** A shared cache that does not vary on
   `Sec-CH-Prefers-Color-Scheme` replays one visitor's `Critical-CH` answer to the
   next visitor and the browser reloads in a loop. Do not send `Critical-CH` from the
   app, the web server or a middleware; if the site needs the client hint, it varies
   on it or asks for it with JavaScript. (The Atakumi website removed a colour-scheme
   `Critical-CH` header for this reason on 2026-11-18.)
7. **The public hostname is a CNAME to the pull zone, DNS only** (grey cloud in
   Cloudflare), and **SSL is verified in Bunny**.

## Why these settings

These are the root causes found while putting stage.atakumi.com behind Bunny on
18 November 2026:

| Symptom | Cause | Setting that fixes it |
| --- | --- | --- |
| The site reloads endlessly | Vary Cache "URL Query String" was off, so `/?_rsc=...` got the cached HTML | Vary Cache → URL Query String on |
| The site reloads endlessly | A `Critical-CH` colour-scheme header replayed through the shared cache | no `Critical-CH` header |
| A redirect loop | the origin URL was `http` | origin `https://` |
| A redirect to the origin hostname | no Forward Host Header, or the public hostname was not on the Coolify app | forward the host header and add both hostnames |
| An admin or a logged-in user gets a public cached page or API response | no no-cache rule | the edge rule above |

## Applying it to a site (owner)

Do this per environment (stage, then production), on the machine named in each step.

1. **Cloudflare, DNS**: add `origin-<environment>.<domain>` as an A record to the
   Coolify server, **DNS only** (grey cloud). Add the public hostname as a CNAME to
   the pull zone, **DNS only**.
2. **Coolify, the app's Domains**: open the app, add `https://origin-<environment>.<domain>`,
   save, then add `https://<public-host>`, save. The origin URL must be reachable over
   HTTPS before the next step.
3. **Bunny, the pull zone, Origin**: set the Origin URL to
   `https://origin-<environment>.<domain>` and turn **Forward Host Header** on.
4. **Bunny, the pull zone, Caching**: open **Vary Cache** and tick **URL Query
   String**.
5. **Bunny, the pull zone, Edge Rules**: create the rule named **"No cache for admin,
   API and logged in"**, set **Override Cache Time** to `0`, and add the four matches
   from the section above ("match any"). Save and enable it.
6. **Bunny, SSL**: wait until the certificate for the public hostname is issued and
   verified.
7. **The app**: remove any `Critical-CH` header and confirm every configured public
   URL is `https://`.
8. **Check** it with the commands below and record the result in the project's
   `docs/infrastructure.md`.

## Checking a site (QA)

1. `curl -sI https://<site>` shows no `critical-ch` header. The first request may be
   `CDN-Cache: MISS`; a second request shows `CDN-Cache: HIT`.
2. `curl -sI https://<site>/admin` shows `CDN-Cache: BYPASS`.
3. `curl -sI https://<site>/api/health` (or any real API path) shows
   `CDN-Cache: BYPASS`.
4. `curl -sI -H "Cookie: payload-token=check" https://<site>/` shows
   `CDN-Cache: BYPASS`. Use the site's own login cookie name when it is not Payload.
5. `curl -sI "https://<site>/?_rsc=check"` twice: the second request shows
   `CDN-Cache: HIT` and the response is the data request, not the cached HTML.
6. Open the site in a new incognito window. It loads once and does not reload.

`curl.exe` is the Windows spelling of the same commands.

## Where each site records it

Each project keeps `docs/infrastructure.md` (copied from
`templates/docs/infrastructure.md`) with its own hostnames, pull zone, the date it
was applied and the check results. That document is the per-site evidence; this file
is the rule.
