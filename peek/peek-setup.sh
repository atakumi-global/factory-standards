#!/usr/bin/env bash
# peek-setup: get this Linux or macOS computer ready to open the factory's dev previews.
# Run it once, with the values from the factory owner's invitation (copy the whole line):
#
#   bash peek-setup.sh 10.77.0.1 2222 "ssh-ed25519 AAAA..." 10.77.0.N "<server vpn key>" <ip>:<port>
#
# Needs WireGuard (macOS: the WireGuard app plus "brew install wireguard-tools";
# Linux: the wireguard-tools package), ssh and curl.
# What it does (nothing else, and nothing outside your own user account):
#   1. Creates your WireGuard key and the tunnel file ~/factory-peek/factory-peek.conf
#      (kept if it exists). The tunnel carries only the traffic to the review server.
#   2. Creates an SSH key only for previews: ~/.ssh/factory_peek_ed25519 (kept if it exists).
#   3. Adds the host "factory-peek" to ~/.ssh/config and pins the server's host key
#      in ~/.ssh/known_hosts, so ssh never has to ask whether to trust it.
#   4. Installs the "peek" command into ~/.local/bin.
#   5. Prints your two PUBLIC keys: send them to the factory owner. The private keys
#      never leave this computer.
# Safe to run again (e.g. to update peek, or with a new invitation).
set -euo pipefail
BASE="${FACTORY_PEEK_BASE:-https://raw.githubusercontent.com/atakumi-global/factory-standards/main/peek}"
server="${1:-}"; port="${2:-}"; hostkey="${3:-}"; vpn_ip="${4:-}"; vpn_server_key="${5:-}"; endpoint="${6:-}"
usage() {
  echo 'usage: bash peek-setup.sh <server> <port> "<host key>" <vpn address> "<vpn server key>" <endpoint>' >&2
  echo "       (copy the whole line from the invitation)" >&2
  exit 2
}
ip4='^[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}\.[0-9]{1,3}$'
[[ "$server" =~ $ip4 ]] && [[ "$vpn_ip" =~ $ip4 ]] && [[ "$port" =~ ^[0-9]{1,5}$ ]] || usage
[[ "$vpn_server_key" =~ ^[A-Za-z0-9+/]{42}[AEIMQUYcgkosw480]=$ ]] || usage
[[ "$endpoint" =~ ^[A-Za-z0-9.-]+:[0-9]{1,5}$ ]] || usage
read -r hk_type hk_data _ <<< "$hostkey"
[[ "${hk_type:-}" =~ ^(ssh-ed25519|ecdsa-sha2-nistp256|ssh-rsa)$ ]] && [[ "${hk_data:-}" =~ ^[A-Za-z0-9+/=]+$ ]] || usage
# Reviewer and owner are different roles: never both on one computer. The owner's own
# command ("review", from factory-ops) has full control of previews; peek is the
# restricted reviewer access.
owner_review="$(command -v review 2>/dev/null || true)"
for f in "$owner_review" "$HOME/.local/bin/review"; do
  [ -n "$f" ] && [ -e "$f" ] || continue
  t="$f"
  while [ -L "$t" ]; do
    l="$(readlink "$t")"; case "$l" in /*) t="$l" ;; *) t="$(dirname "$t")/$l" ;; esac
  done
  # The owner's review (factory-ops) reads the private registry; a reviewer has none.
  if grep -q 'factory-config/projects.yaml' "$t" 2>/dev/null; then
    echo "This computer has the factory owner's review command ($f, from factory-ops)." >&2
    echo "peek is for reviewers and is not installed next to it." >&2
    exit 1
  fi
done
for c in ssh ssh-keygen curl; do command -v "$c" >/dev/null || { echo "missing: $c" >&2; exit 1; }; done
command -v wg >/dev/null || {
  echo "missing: wg (macOS: brew install wireguard-tools; Linux: install wireguard-tools)" >&2; exit 1; }

echo "== 1. WireGuard tunnel factory-peek"
vpn_dir="$HOME/factory-peek"; tunnel="$vpn_dir/factory-peek.conf"
mkdir -p "$vpn_dir"; chmod 700 "$vpn_dir"
private=""
[ -f "$tunnel" ] && private="$(sed -n 's/^PrivateKey[[:space:]]*=[[:space:]]*\([^[:space:]]*\)[[:space:]]*$/\1/p' "$tunnel" | head -1)"
if [ -n "$private" ]; then echo "kept your key from $tunnel"
else private="$(wg genkey)"; echo "created your WireGuard key"; fi
vpn_public="$(printf '%s\n' "$private" | wg pubkey)"
(umask 077; cat > "$tunnel" <<EOF
[Interface]
PrivateKey = $private
Address = $vpn_ip/32

[Peer]
PublicKey = $vpn_server_key
Endpoint = $endpoint
AllowedIPs = $server/32
PersistentKeepalive = 25
EOF
)
echo "ok: $tunnel"

echo "== 2. SSH key for previews"
mkdir -p "$HOME/.ssh"; chmod 700 "$HOME/.ssh"
key="$HOME/.ssh/factory_peek_ed25519"
if [ -f "$key" ]; then
  echo "kept: $key"
else
  # No passphrase: the key only opens the previews you were given, only through your
  # factory-peek tunnel, and peek runs the SSH tunnel in the background.
  ssh-keygen -q -t ed25519 -N '' -C "$(id -un)@$(hostname -s 2>/dev/null || hostname) factory-peek" -f "$key"
  echo "created: $key"
fi

echo "== 3. SSH host factory-peek"
config="$HOME/.ssh/config"; touch "$config"; chmod 600 "$config"
tmp="$(mktemp)"
{
  echo '# factory-peek: dev previews (written by peek-setup)'
  echo 'Host factory-peek'
  echo "  HostName $server"
  echo "  Port $port"
  echo '  User review'
  echo '  IdentityFile ~/.ssh/factory_peek_ed25519'
  echo '  IdentitiesOnly yes'
  echo '  ServerAliveInterval 30'
  echo '# end factory-peek'
  echo
  # First value wins in ssh_config, so the block goes first; the old block is dropped.
  awk '/^# factory-peek: dev previews/ {skip=1; next} skip && /^# end factory-peek/ {skip=0; next} !skip' "$config"
} > "$tmp"
cat "$tmp" > "$config"; rm -f "$tmp"
if [ "$port" = 22 ]; then host_id="$server"; else host_id="[$server]:$port"; fi
known="$HOME/.ssh/known_hosts"; touch "$known"
grep -vF "$host_id " "$known" > "$known.tmp" || true
echo "$host_id $hk_type $hk_data" >> "$known.tmp"; mv "$known.tmp" "$known"; chmod 600 "$known"
echo "ok: factory-peek = review@$server:$port, host key pinned"

echo "== 4. The peek command"
mkdir -p "$HOME/.local/bin"
curl -fsSL "$BASE/peek" -o "$HOME/.local/bin/peek.new"
head -1 "$HOME/.local/bin/peek.new" | grep -q '^#!/usr/bin/env bash' || { echo "download of peek failed" >&2; exit 1; }
chmod +x "$HOME/.local/bin/peek.new"; mv "$HOME/.local/bin/peek.new" "$HOME/.local/bin/peek"
echo "ok: $HOME/.local/bin/peek"
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *)
  echo "Add ~/.local/bin to your PATH (in ~/.bashrc or ~/.zshrc):"
  echo '  export PATH="$HOME/.local/bin:$PATH"' ;;
esac

echo
echo "== 5. Send these two PUBLIC keys to the factory owner:"
echo
echo "ssh:       $(cat "$key.pub")"
echo "wireguard: $vpn_public"
echo
echo "Next, import the tunnel file $tunnel:"
echo "  macOS:  WireGuard app > Import Tunnel(s) from File"
echo "  Linux:  nmcli connection import type wireguard file $tunnel   (or: sudo wg-quick up $tunnel)"
echo "When the owner confirms you are added: switch the factory-peek tunnel on, open a"
echo "new terminal and run:   peek status"
