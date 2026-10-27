# Reviewing dev previews

The factory runs each project's latest `dev` as a preview on its agent server. With
access, you open a preview in your own browser with one command:

```
review status               the previews you can open, and whether they run
review airtime start        start it if needed and open it in your browser
review airtime status       its state and your tunnel
review airtime stop         close your tunnel
```

The project is its short name (the Plane identifier, e.g. `airtime`), its key
(`ATAK-AIRTIME`) or its full name; `review start airtime` works too. No window has to
stay open. A preview that nobody uses stops by itself after 2 hours and starts again
when someone opens it; the first start can take a few minutes. A push to `dev` shows
within about 2 minutes: refresh the browser.

## Getting access (once)

You need an invitation from the factory owner: it holds the server address and the
server's key, and the exact commands below with those filled in.

1. **WireGuard.** Install the WireGuard app (https://www.wireguard.com/install/) and
   import the configuration file the owner sends you. Switch it on when you review.
2. **Run the setup script** from the invitation:
   - Windows (PowerShell): `review-setup.ps1 -Server <address> -HostKey "<key>"`
   - macOS or Linux: `bash review-setup.sh <address> "<key>"`

   It only changes things in your own account:
   - a new SSH key just for previews, `~/.ssh/factory_review_ed25519`;
   - a `factory-review` entry in `~/.ssh/config` and the server's key in
     `~/.ssh/known_hosts` (so ssh never asks whether to trust the server);
   - the `review` command (Windows: your PowerShell profile; macOS/Linux:
     `~/.local/bin/review`).
3. **Send the owner the public key** the script prints at the end (one line starting
   with `ssh-ed25519`, ending in `factory-review`). Never send the file without `.pub`.
4. When the owner says you are added: WireGuard on, new terminal, `review status`.

Running the setup script again is safe: it keeps your key and updates `review`.

## What the access allows

Only what `review` does: list your projects, start a preview, see its status, and
forward that preview's ports to your computer. There is no shell, no other server port
and no other project. You cannot stop a preview for others; closing your tunnel is
enough.

## When something does not work

| Message | Meaning |
| --- | --- |
| `Permission denied (publickey)` | Your key is not added yet, or `review-setup` ran under another user account |
| `Connection timed out` / `No route to host` | WireGuard is off, or not connected |
| `Host key verification failed` | The server's key changed; ask the owner for a new invitation and run the setup again |
| `port ... already in use` | Something on your computer uses the project's ports (e.g. 3500-3509). Use other local ports: `FACTORY_REVIEW_PORT_OFFSET=10000 review airtime start` (PowerShell: `$env:FACTORY_REVIEW_PORT_OFFSET = 10000` first); the preview then opens on 13500 |
| `No preview '...' for you` | That project is not shared with you; it lists the ones that are |
