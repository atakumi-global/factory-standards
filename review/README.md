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

You need an invitation from the factory owner: it holds the exact setup command with
the server's address and keys filled in.

1. **Install WireGuard**: https://www.wireguard.com/install/ (macOS: the WireGuard app
   and `brew install wireguard-tools`; Linux: the `wireguard-tools` package).
2. **Run the setup command** from the invitation:
   - Windows (PowerShell): `review-setup.ps1 -Server ... -Port ... -HostKey "..." -VpnAddress ... -VpnServerKey "..." -VpnEndpoint ...`
   - macOS or Linux: `bash review-setup.sh <server> <port> "<host key>" <vpn address> "<vpn server key>" <endpoint>`

   It only changes things in your own account:
   - your WireGuard key and the tunnel file `factory-review.conf` (in a
     `factory-review` folder in your home folder). The tunnel carries only the traffic
     to the review server, nothing else of yours;
   - a new SSH key just for previews, `~/.ssh/factory_review_ed25519`;
   - a `factory-review` entry in `~/.ssh/config` and the server's key in
     `~/.ssh/known_hosts` (so ssh never asks whether to trust the server);
   - the `review` command (Windows: your PowerShell profiles; macOS/Linux:
     `~/.local/bin/review`).
3. **Import the tunnel file** in the WireGuard app (Windows/macOS: "Import tunnel(s) from
   file"; Linux: `nmcli connection import type wireguard file ~/factory-review/factory-review.conf`).
4. **Send the owner the two public keys** the script prints at the end (`ssh:` and
   `wireguard:`). Your private keys never leave your computer.
5. When the owner says you are added: switch the `factory-review` tunnel on, open a new
   terminal, `review status`.

Running the setup again is safe: it keeps your keys and updates `review`.

## What the access allows

Only what `review` does: list your projects, start a preview, see its status, and
forward that preview's ports to your computer. The tunnel reaches only the review
server's SSH entrance; there is no shell, no other server port, no other project and
nothing else on the owner's network. You cannot stop a preview for others; closing your tunnel is
enough.

## When something does not work

| Message | Meaning |
| --- | --- |
| `Permission denied (publickey)` | Your key is not added yet, or `review-setup` ran under another user account |
| `Connection timed out` / `No route to host` | The `factory-review` tunnel is off, or has no handshake yet (the WireGuard app shows "latest handshake" once the owner added your key) |
| `Host key verification failed` | The server's key changed; ask the owner for a new invitation and run the setup again |
| `port ... already in use` | Something on your computer uses the project's ports (e.g. 3500-3509). Use other local ports: `FACTORY_REVIEW_PORT_OFFSET=10000 review airtime start` (PowerShell: `$env:FACTORY_REVIEW_PORT_OFFSET = 10000` first); the preview then opens on 13500 |
| `No preview '...' for you` | That project is not shared with you; it lists the ones that are |
