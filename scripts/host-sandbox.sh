#!/usr/bin/env bash
# Sandbox-verify a host config from this checkout without touching the running system.
#
#   scripts/host-sandbox.sh ramsay --tier eval        eval only: option errors, eval warnings
#   scripts/host-sandbox.sh ramsay                    eval + build the system closure
#   scripts/host-sandbox.sh --all --tier eval         every host in one pass
#   scripts/host-sandbox.sh macmini                   darwin from Linux: module check only
#   scripts/host-sandbox.sh ramsay --tier vm          build the QEMU image for the config
#   scripts/host-sandbox.sh ramsay --tier vm --vm-boot
#                                                     then boot it and wait for the login prompt
#   scripts/host-sandbox.sh ramsay --plan             print the nix plan, build nothing
#
# Tiers, cheapest first:
#
#   eval   Evaluate the configuration. Catches Nix eval errors and shows the
#          option warnings nix prints. 38 s for the first host of a tree; nix
#          caches the evaluation of that tree, so the rest are cheap.
#   build  Build the closure `nh os switch` would install. Catches every compile
#          error. Instant when the store already holds it.
#   vm     Build config.system.build.vm, then optionally boot it. Catches
#          activation and boot failures a build cannot see.
#
# What one check runs depends on the host kind and this machine. A derivation for
# another platform cannot even be instantiated here, so off-platform hosts get a
# module check instead: one string option forces the whole option set to merge,
# which catches every undeclared option name without building anything.
#
#   nixos on this platform    eval the toplevel .drv, then build it
#   nixos off this platform   eval one option (module check)
#   darwin on this platform   eval the system .drv, then build it
#   darwin off this platform  eval one option (module check)
#   droid on this platform    eval the activation .drv, then build it
#
# Nothing here activates a configuration. The commands run are `nix eval`,
# `nix build`, and the generated run-*-vm script, so the running system keeps its
# current generation. `nh os switch` stays manual.
#
# The flake ref defaults to the committed tree of $PWD (git mode), so a new file
# needs `git add -N` before nix sees it. A dirty tree costs a fresh store copy per
# run: commit first, or pass --allow-dirty.
set -euo pipefail

usage() {
  cat <<'EOF'
Usage: host-sandbox.sh [options] HOST [HOST ...]
       host-sandbox.sh --all [options]

Verify a host config without activating it.

  HOST            ramsay | goofeus | goofydesky | goofyenvy | minimaiso
                  macmini | x86-avd | droid
  --tier TIER     eval | build | vm                     (default: build)
  --all           Ramsay Goofeus GoofyDesky GoofyEnvy MacMini
  --flake REF     flake ref to evaluate (default: the committed tree of $PWD)
  --attr ATTR     single flake attribute to check, replacing the host table
  --plan          build tier: print the nix plan instead of building
  --vm-boot       with --tier vm: boot the image headless, wait for the login prompt
  --log-dir DIR   log directory  (default: ${TMPDIR:-/tmp}/agent-tmp/NixConfig)
  --json          one JSON object per check on stdout
  --allow-dirty   run on an uncommitted tree (nix copies the whole tree per run)
  -h, --help      print this text

Environment: FLAKE, ATTR, LOGDIR, TIMEOUT (1800), BOOT_TIMEOUT (300), QEMU_OPTS

The VM memory and disk size come from the built image (virtualisation.memorySize
and diskImage), not from this script.
EOF
}

die() {
  printf 'host-sandbox: %s\n' "$*" >&2
  exit 2
}

lc() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

TIER=build
FLAKE=${FLAKE:-}
ATTR=${ATTR:-}
LOGDIR=${LOGDIR:-${TMPDIR:-/tmp}/agent-tmp/NixConfig}
TIMEOUT=${TIMEOUT:-1800}
BOOT_TIMEOUT=${BOOT_TIMEOUT:-300}
ALL=0
PLAN=0
VM_BOOT=0
JSON=0
ALLOW_DIRTY=0
hosts=()

# Accept both `--opt value` and `--opt=value`.
args=()
for a in "$@"; do
  case "$a" in
    --tier=* | --flake=* | --attr=* | --log-dir=*)
      args+=("${a%%=*}" "${a#*=}")
      ;;
    *) args+=("$a") ;;
  esac
done
set -- ${args[@]+"${args[@]}"}

while [ $# -gt 0 ]; do
  case "$1" in
    --tier) [ $# -ge 2 ] || die '--tier needs a value'; TIER=$2; shift 2 ;;
    --flake) [ $# -ge 2 ] || die '--flake needs a value'; FLAKE=$2; shift 2 ;;
    --attr) [ $# -ge 2 ] || die '--attr needs a value'; ATTR=$2; shift 2 ;;
    --log-dir) [ $# -ge 2 ] || die '--log-dir needs a value'; LOGDIR=$2; shift 2 ;;
    --all) ALL=1; shift ;;
    --plan) PLAN=1; shift ;;
    --vm-boot) VM_BOOT=1; shift ;;
    --json) JSON=1; shift ;;
    --allow-dirty) ALLOW_DIRTY=1; shift ;;
    -h | --help) usage; exit 0 ;;
    -*) die "unknown option: $1" ;;
    *) hosts+=("$1"); shift ;;
  esac
done

case "$TIER" in
  eval | build | vm) ;;
  *) die "unknown --tier: $TIER (eval | build | vm)" ;;
esac

if [ -n "$ATTR" ]; then
  if [ ${#hosts[@]} -eq 0 ]; then hosts=(custom); fi
elif [ "$ALL" = 1 ]; then
  hosts=(Ramsay Goofeus GoofyDesky GoofyEnvy MacMini)
fi
[ ${#hosts[@]} -gt 0 ] || die 'no host given. Pass a HOST or --all. See --help.'

local_platform() {
  case "$(uname -m)" in
    x86_64) printf 'x86_64-linux\n' ;;
    aarch64) printf 'aarch64-linux\n' ;;
    arm64) printf 'aarch64-darwin\n' ;;
    *) printf 'unknown\n' ;;
  esac
}

# Host name -> "<flake name> <kind> <target system>".
# `droid` picks the configuration built for this machine: the aarch64 one on a
# phone, the x86 AVD one everywhere else.
hostinfo() {
  case "$(lc "$1")" in
    ramsay) printf 'Ramsay nixos x86_64-linux\n' ;;
    goofeus) printf 'Goofeus nixos x86_64-linux\n' ;;
    goofydesky) printf 'GoofyDesky nixos x86_64-linux\n' ;;
    goofyenvy) printf 'GoofyEnvy nixos x86_64-linux\n' ;;
    minimaiso) printf 'minimalIso nixos x86_64-linux\n' ;;
    macmini) printf 'MacMini darwin aarch64-darwin\n' ;;
    x86-avd) printf 'x86-avd droid x86_64-linux\n' ;;
    droid)
      if [ "$(local_platform)" = aarch64-linux ]; then
        printf 'default droid aarch64-linux\n'
      else
        printf 'x86-avd droid x86_64-linux\n'
      fi
      ;;
    *) return 1 ;;
  esac
}

# What the eval tier runs for a host: the full derivation check, or the module
# check. `full` forces the .drv; `lint` forces one string option, which still
# merges every option declaration and catches undeclared option names.
eval_mode() {
  local kind=$1 target=$2
  if [ "$target" = "$(local_platform)" ]; then
    printf 'full\n'
  else
    printf 'lint\n'
  fi
}

# Flake attribute for a host at one tier. Empty means the tier does not apply.
# `full` forces the real derivation; `lint` points at the configuration attr, so
# nix merges every option declaration without instantiating a derivation.
attr_for() {
  local name=$1 kind=$2 tier=$3 mode=${4:-full}
  local base
  case "$kind" in
    nixos) base="nixosConfigurations.$name" ;;
    darwin) base="darwinConfigurations.$name" ;;
    droid) base="nixOnDroidConfigurations.$name" ;;
    *) printf '\n'
      return 0 ;;
  esac
  if [ "$tier" = eval ] && [ "$mode" = lint ]; then
    printf '%s\n' "$base"
    return 0
  fi
  case "$kind:$tier" in
    nixos:eval) printf '%s.config.system.build.toplevel.drvPath\n' "$base" ;;
    nixos:build) printf '%s.config.system.build.toplevel\n' "$base" ;;
    nixos:vm) printf '%s.config.system.build.vm\n' "$base" ;;
    darwin:eval) printf '%s.system.drvPath\n' "$base" ;;
    darwin:build) printf '%s.system\n' "$base" ;;
    droid:eval) printf '%s.activationPackage.drvPath\n' "$base" ;;
    droid:build) printf '%s\n' "$base" ;;
    *) printf '\n' ;;
  esac
}

# Resolve the flake ref once. A clean git ref is cached by nix; a dirty tree is not.
if [ -z "$FLAKE" ]; then
  FLAKE=$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null) ||
    die "$PWD is not a git repo. Pass --flake REF."
  if [ -n "$(git -C "$FLAKE" status --porcelain)" ] && [ "$ALLOW_DIRTY" != 1 ]; then
    die "$FLAKE has uncommitted changes. Commit them or pass --allow-dirty.
  A dirty tree makes nix copy the whole tree into the store on every run
  (AGENTS.md, Flake evals)."
  fi
  FLAKE="git+file://$FLAKE"
fi

mkdir -p "$LOGDIR" || die "cannot create $LOGDIR"
SUMMARY="$LOGDIR/last-run.txt"
: >"$SUMMARY"

failed=0

report() {
  local host=$1 tier=$2 status=$3 secs=$4 detail=$5 warn=$6 log=$7
  if [ "$JSON" = 1 ]; then
    printf '{"host":"%s","tier":"%s","status":"%s","seconds":%s,"out":"%s","warnings":%s,"log":"%s"}\n' \
      "$host" "$tier" "$status" "$secs" "$(printf '%s' "$detail" | sed 's/\\/\\\\/g; s/"/\\"/g')" \
      "$warn" "$log"
  else
    printf '%-11s %-5s %-5s %5ss %s%s\n' "$host" "$tier" "$status" "$secs" \
      "${detail:0:92}" "$([ "$warn" != 0 ] && printf ' [%s eval warnings]' "$warn")"
  fi
  printf '%-11s %-5s %-5s %5ss %s\n' "$host" "$tier" "$status" "$secs" "$detail" >>"$SUMMARY"
}

skip() {
  local host=$1 tier=$2 reason=$3
  if [ "$JSON" = 1 ]; then
    printf '{"host":"%s","tier":"%s","status":"skip","reason":"%s"}\n' "$host" "$tier" "$reason"
  else
    printf '%-11s %-5s %-5s        %s\n' "$host" "$tier" skip "$reason"
  fi
  printf '%-11s %-5s %-5s        %s\n' "$host" "$tier" skip "$reason" >>"$SUMMARY"
}

# First useful line from a boot log: the login prompt, else the last real QEMU line.
detail_for_boot() {
  local line
  line=$(grep -aE 'login:|Startup finished' "$1" 2>/dev/null | head -1)
  [ -n "$line" ] || line=$(grep -av '^\[' "$1" 2>/dev/null | tail -1)
  printf '%s' "$line" | tr -d '\r' | cut -c1-90
}

# Boot a built VM headless and wait for the login prompt.
boot_vm() {
  local host=$1 out=$2
  local bin pid=0 ok=0 i log secs detail
  bin=$(ls "$out"/bin/ 2>/dev/null | head -1)
  [ -n "$bin" ] || {
    report "$host" boot fail 0 "no run script in $out/bin" 0 "$LOGDIR/$host.boot.log"
    failed=1
    return 0
  }
  log="$LOGDIR/$host.boot.log"
  secs=$(date +%s)
  # The run script fixes -m and the disk size, so set the image path instead of -m.
  NIX_DISK_IMAGE="$LOGDIR/$host.qcow2" \
    QEMU_OPTS="${QEMU_OPTS:--display none -nographic}" \
    "$out/bin/$bin" >"$log" 2>&1 &
  pid=$!
  for ((i = 0; i < BOOT_TIMEOUT; i++)); do
    if grep -qE 'login:|systemd\[1\]: Startup finished' "$log" 2>/dev/null; then
      ok=1
      break
    fi
    kill -0 "$pid" 2>/dev/null || break
    sleep 1
  done
  kill "$pid" 2>/dev/null || true
  wait "$pid" 2>/dev/null || true
  secs=$(( $(date +%s) - secs ))
  report "$host" boot "$( [ "$ok" = 1 ] && echo pass || echo fail)" "$secs" \
    "$(detail_for_boot "$log")" 0 "$log"
  [ "$ok" = 1 ] || failed=1
}

# One check: run it, keep the output in a log, print one summary line.
check() {
  local host=$1 tier=$2 attr=$3 mode=$4
  local ref="$FLAKE#$attr" cmd out errf rc secs log detail warn status

  case "$tier:$mode" in
    eval:full) cmd=(nix eval --raw "$ref") ;;
    eval:lint) cmd=(nix eval --apply builtins.typeOf "$ref") ;;
    build:plan) cmd=(nix build --no-link --dry-run "$ref") ;;
    build:*) cmd=(nix build --no-link --print-out-paths "$ref") ;;
    vm:*) cmd=(nix build --no-link --print-out-paths "$ref") ;;
    *) die "check: bad mode $mode for tier $tier" ;;
  esac

  log="$LOGDIR/$host.$tier.log"
  errf="$LOGDIR/.$host.$tier.stderr"
  secs=$(date +%s)
  out=$(timeout "$TIMEOUT" "${cmd[@]}" 2>"$errf") && rc=0 || rc=$?
  secs=$(( $(date +%s) - secs ))
  # Keep stdout (the answer) first, then nix's progress and warnings.
  {
    printf '%s\n' "$out"
    cat "$errf" 2>/dev/null
  } >"$log" 2>/dev/null || true
  rm -f "$errf" 2>/dev/null || true

  status=pass
  if [ "$rc" != 0 ]; then
    status=fail
    failed=1
  elif [ "$mode" = lint ] || [ "$mode" = plan ]; then
    status=$mode
  fi

  warn=$(grep -c '^evaluation warning' "$log" 2>/dev/null || true)
  [ -n "$warn" ] || warn=0
  if [ "$mode" = lint ]; then
    detail="$attr"
  elif [ -n "$out" ]; then
    detail=$(printf '%s' "$out" | head -1 | cut -c1-120)
  else
    detail=$(grep -v '^evaluation warning' "$log" 2>/dev/null | head -1 | cut -c1-120)
  fi
  report "$host" "$tier" "$status" "$secs" "$detail" "$warn" "$log"
  if [ "$status" = fail ]; then
    printf '%s\n' "$out" | grep -v '^evaluation warning' | head -20 >&2
  fi

  if [ "$tier" = vm ] && [ "$status" = pass ] && [ "$VM_BOOT" = 1 ]; then
    boot_vm "$host" "$out"
  fi
}

for h in "${hosts[@]}"; do
  if [ -n "$ATTR" ]; then
    check "$h" "$TIER" "$ATTR" "$( [ "$TIER" = eval ] && echo full || echo build )"
    continue
  fi
  info=$(hostinfo "$h") || {
    printf 'host-sandbox: unknown host: %s (see --help)\n' "$h" >&2
    failed=1
    continue
  }
  set -- $info
  name=$1
  kind=$2
  target=$3
  here=$(local_platform)

  # eval tier: the strongest check available for this host on this machine.
  if [ "$TIER" != vm ]; then
    emode=$(eval_mode "$kind" "$target")
    a=$(attr_for "$name" "$kind" eval "$emode")
    if [ -n "$a" ]; then check "$name" eval "$a" "$emode"; fi
  fi

  # build tier: only where nix can build that platform.
  if [ "$TIER" = build ]; then
    if [ "$target" != "$here" ]; then
      skip "$name" build "not buildable on $here"
    else
      a=$(attr_for "$name" "$kind" build)
      if [ -n "$a" ]; then
        if [ "$PLAN" = 1 ]; then
          check "$name" build "$a" plan
        else
          check "$name" build "$a" build
        fi
      fi
    fi
  fi

  # vm tier: NixOS on this machine only.
  if [ "$TIER" = vm ]; then
    a=$(attr_for "$name" "$kind" vm)
    if [ -z "$a" ]; then
      skip "$name" vm "no config.system.build.vm for $kind"
    elif [ "$target" != "$here" ]; then
      skip "$name" vm "no QEMU image for $target on $here"
    else
      if [ "$PLAN" = 1 ]; then
        check "$name" vm "$a" plan
      else
        check "$name" vm "$a" vm
      fi
    fi
  fi
done

exit "$failed"
