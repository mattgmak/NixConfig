#!/usr/bin/env bash
# Materialize the current NixConfig revision on Goofeus and activate it there.
#
# /root/NixConfig becomes a symlink to the flake source store path Nix evaluates
# (gitignore filtered, submodule contents included), so the directory is exactly
# the revision that gets built, needs no git maintenance, and cannot drift. The
# gcroot keeps that source alive across nix-collect-garbage.
#
#   scripts/deploy-goofeus.sh              sync + boot entry + activate
#   scripts/deploy-goofeus.sh --dir-only   only materialize the directory
#   scripts/deploy-goofeus.sh --no-boot    activate without touching the boot entry
#   scripts/deploy-goofeus.sh --dry        print what nh would do
#
# HOST, ATTR, DEST and GCROOT override the defaults below.
set -euo pipefail

REPO=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
HOST=${HOST:-root@goofeus}
ATTR=${ATTR:-Goofeus}
DEST=${DEST:-/root/NixConfig}
GCROOT=${GCROOT:-/nix/var/nix/gcroots/deployed-nixconfig}
REPO_URL=${REPO_URL:-https://github.com/mattgmak/NixConfig}

dry=0
dir_only=0
no_boot=0
while [ $# -gt 0 ]; do
  case "$1" in
    -n | --dry) dry=1 ;;
    --dir-only) dir_only=1 ;;
    --no-boot) no_boot=1 ;;
    *)
      printf 'deploy-goofeus: unknown argument: %s\n' "$1" >&2
      exit 2
      ;;
  esac
  shift
done

log() { printf 'deploy-goofeus: %s\n' "$*"; }

src=$(nix flake metadata --json --no-write-lock-file "$REPO" | jq -r .path)
rev=$(git -C "$REPO" rev-parse HEAD)
dirty=$(git -C "$REPO" status --porcelain | wc -l | tr -d ' ')
untracked=$(git -C "$REPO" ls-files --others --exclude-standard)
log "revision $rev ($dirty uncommitted file(s))"
log "source $src"

# Nix's flake source holds tracked paths only, so a new file that was never added
# is silently absent from the deployed tree.
if [ -n "$untracked" ]; then
  log "warning: untracked files are not part of the flake source — git add them if the config needs them:"
  printf '%s\n' "$untracked" | awk 'NR <= 10 { print "  " $0 }'
fi

if [ "$dry" = 0 ]; then
  nix copy --to "ssh://$HOST" "$src"

  ssh "$HOST" "bash -s -- '$src' '$DEST' '$GCROOT' '$rev' '$dirty' '$REPO_URL'" <<'REMOTE'
set -euo pipefail
src=$1
dest=$2
gcroot=$3
rev=$4
dirty=$5
repoUrl=$6

# A real directory here is a leftover checkout: move it aside, never delete it.
if [ -e "$dest" ] && [ ! -L "$dest" ]; then
  old="$dest.old-$(date +%Y%m%d%H%M%S)"
  echo "deploy-goofeus: moving existing directory $dest -> $old"
  mv "$dest" "$old"
fi

ln -sfn "$src" "$dest"
ln -sfn "$src" "$gcroot"
printf 'rev=%s\ndirty=%s\nsrc=%s\nsynced_at=%s\n' \
  "$rev" "$dirty" "$src" "$(date -Is)" >"$dest.rev"

# Also sync agent's ~/NixConfig to the deployed revision.
agentRepo="/home/agent/NixConfig"
if [ ! -d "$agentRepo/.git" ]; then
  echo "deploy-goofeus: cloning $repoUrl → $agentRepo"
  sudo -u agent git clone --recurse-submodules -b main "$repoUrl" "$agentRepo"
else
  echo "deploy-goofeus: fast-forwarding agent repo"
  sudo -u agent git -C "$agentRepo" fetch origin main
  sudo -u agent git -C "$agentRepo" merge --ff-only origin/main || true
  sudo -u agent git -C "$agentRepo" submodule update --init --recursive || true
fi
REMOTE

  remote_path=$(ssh "$HOST" "nix flake metadata --json '$DEST' | jq -r .path")
  if [ "$remote_path" != "$src" ]; then
    printf 'deploy-goofeus: %s resolves to %s, expected %s\n' "$DEST" "$remote_path" "$src" >&2
    exit 1
  fi
  # agent-sesh is the one vendor tree Goofeus evaluation cannot do without.
  ssh "$HOST" "test -f '$src/vendor/mattgmak/agent-sesh/flake.nix'"
  log "$DEST -> $src"
fi

if [ "$dir_only" = 1 ]; then
  exit 0
fi

nh_args=(-H "$ATTR" --target-host "$HOST" --build-host "$HOST")
if [ "$dry" = 1 ]; then
  nh_args+=(--dry)
fi

if [ "$no_boot" = 0 ]; then
  log "writing boot entry"
  nh os boot "${nh_args[@]}" --install-bootloader
fi

log "activating"
nh os switch "${nh_args[@]}"
