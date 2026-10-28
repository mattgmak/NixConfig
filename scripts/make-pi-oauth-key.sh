#!/usr/bin/env bash
# One-off: create the encrypted-file OAuth key and seal it for the pi hosts.
# The plaintext key never leaves this directory and has no copy in the repo.
set -euo pipefail

repo=$(cd "$(dirname "$0")/.." && pwd)
work="${TMPDIR:-/tmp}/agent-tmp/nixconfig/secretgen"

umask 077
install -d -m 700 "$work"
cd "$repo"

head -c 32 /dev/urandom | base64 >"$work/key"

printf '%s\n' \
  'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAINKuInd6TqSlVSu3qottOYYODNbdVC07mfEs7Idbo20u' \
  'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIMq/zGCOmrHUwNRwjDsj8Sw0PDbnMd3Ck7H/ZKsHKPkM goofy@GoofyDesky' \
  'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIHcf8d+U2aI4zO/axcvK97qP1FG9cfwp5CCUuKZEYRu5 goofy@GoofyEnvy' \
  'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIJeW872aIf7gEz8mS6MOLOaheMNpJghqVppQlUYSqq4x' \
  'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIC5KIsxMM9XNnktIidlFgdgLjkAM7hTETiVy5dBYtcgq agent@Goofeus' \
  'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAILvHr70WhwFy98okSEV2hpsiUMZwqVuME+T97Gd6SGvP mattgmak@Matthews-Mac-mini.local' \
  'ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAII1zk63+hPq2dUA/6MUgLW3ryisp/dZQ8GuiPDYpyiFK root@Ramsay' \
  'age1d2cjwq3q74ms05zj4qge8lxlf5ac3nl25ajy8vxeyy2qd2x733xqg43mya' >"$work/recipients.txt"

nix run nixpkgs#age -- -a -R "$work/recipients.txt" -o secrets/pi-mcp-adapter-oauth-file-key.age "$work/key"
chmod 644 secrets/pi-mcp-adapter-oauth-file-key.age

dec=$(nix run nixpkgs#age -- -d -i "$HOME/.ssh/id_ed25519" secrets/pi-mcp-adapter-oauth-file-key.age | tr -d '\n')
case "$dec" in
  ???????????????????????????????????????????=) ;;
  *) echo "decrypted key has the wrong shape" >&2; exit 1 ;;
esac
printf 'decrypt ok, %s chars\n' "${#dec}"

rm -f "$work/key" "$work/recipients.txt"
