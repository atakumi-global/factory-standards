#!/usr/bin/env bash
# review-setup: get this Linux or macOS computer ready to open the factory's dev previews.
# Run it once, with the server address and host key from the factory owner's invitation:
#
#   bash review-setup.sh <address> "<ssh-ed25519 AAAA...>"
#
# What it does (nothing else, and nothing outside your own user account):
#   1. Creates an SSH key only for previews: ~/.ssh/factory_review_ed25519 (kept if it exists).
#   2. Adds the host "factory-review" to ~/.ssh/config and pins the server's host key
#      in ~/.ssh/known_hosts, so ssh never has to ask whether to trust it.
#   3. Installs the "review" command into ~/.local/bin.
#   4. Prints your PUBLIC key: send that to the factory owner. Never send the file
#      without .pub; it stays on this computer.
# Safe to run again (e.g. to update review, or after the server address changes).
set -euo pipefail
BASE="${FACTORY_REVIEW_BASE:-https://raw.githubusercontent.com/atakumi-global/factory-standards/main/review}"
server="${1:-}"; hostkey="${2:-}"
usage() { echo 'usage: bash review-setup.sh <address> "<ssh-ed25519 AAAA...>"  (both from the invitation)' >&2; exit 2; }
[[ "$server" =~ ^[A-Za-z0-9.-]+$ ]] || usage
read -r hk_type hk_data _ <<< "$hostkey"
[[ "${hk_type:-}" =~ ^(ssh-ed25519|ecdsa-sha2-nistp256|ssh-rsa)$ ]] && [[ "${hk_data:-}" =~ ^[A-Za-z0-9+/=]+$ ]] || usage
for c in ssh ssh-keygen curl; do command -v "$c" >/dev/null || { echo "missing: $c" >&2; exit 1; }; done

echo "== 1. SSH key for previews"
mkdir -p "$HOME/.ssh"; chmod 700 "$HOME/.ssh"
key="$HOME/.ssh/factory_review_ed25519"
if [ -f "$key" ]; then
  echo "kept: $key"
else
  # No passphrase: the key only opens previews you were given, from your WireGuard
  # connection, and review runs the tunnel in the background without asking.
  ssh-keygen -q -t ed25519 -N '' -C "$(id -un)@$(hostname -s 2>/dev/null || hostname) factory-review" -f "$key"
  echo "created: $key"
fi

echo "== 2. SSH host factory-review"
config="$HOME/.ssh/config"; touch "$config"; chmod 600 "$config"
tmp="$(mktemp)"
{
  echo '# factory-review: dev previews (written by review-setup)'
  echo 'Host factory-review'
  echo "  HostName $server"
  echo '  User review'
  echo '  IdentityFile ~/.ssh/factory_review_ed25519'
  echo '  IdentitiesOnly yes'
  echo '  ServerAliveInterval 30'
  echo '# end factory-review'
  echo
  # First value wins in ssh_config, so the block goes first; the old block is dropped.
  awk '/^# factory-review: dev previews/ {skip=1; next} skip && /^# end factory-review/ {skip=0; next} !skip' "$config"
} > "$tmp"
cat "$tmp" > "$config"; rm -f "$tmp"
known="$HOME/.ssh/known_hosts"; touch "$known"
grep -v "^$server " "$known" > "$known.tmp" || true
echo "$server $hk_type $hk_data" >> "$known.tmp"; mv "$known.tmp" "$known"; chmod 600 "$known"
echo "ok: factory-review = review@$server, host key pinned"

echo "== 3. The review command"
mkdir -p "$HOME/.local/bin"
curl -fsSL "$BASE/review" -o "$HOME/.local/bin/review.new"
head -1 "$HOME/.local/bin/review.new" | grep -q '^#!/usr/bin/env bash' || { echo "download of review failed" >&2; exit 1; }
chmod +x "$HOME/.local/bin/review.new"; mv "$HOME/.local/bin/review.new" "$HOME/.local/bin/review"
echo "ok: $HOME/.local/bin/review"
case ":$PATH:" in *":$HOME/.local/bin:"*) ;; *)
  echo "Add ~/.local/bin to your PATH (in ~/.bashrc or ~/.zshrc):"
  echo '  export PATH="$HOME/.local/bin:$PATH"' ;;
esac

echo
echo "== 4. Send this PUBLIC key to the factory owner:"
echo
cat "$key.pub"
echo
echo "When the owner confirms you are added: switch on your WireGuard connection, open a"
echo "new terminal and run:   review status"
