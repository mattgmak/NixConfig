#!/usr/bin/env bash
# Sync the "Iosevka global" Stylus style from a Zen export into this repo.
#
# Stylus writes the style list to its own storage. Export it by hand:
#   Stylus manager -> Export -> save to ~/Downloads
# Then run this script. It updates two files:
#   dendritic/home-modules/zen-browser/extensions/stylus.css        the CSS
#   dendritic/home-modules/zen-browser/extensions/stylus-match.json the site filters
# A rebuild gives the next Stylus import the same content.
set -euo pipefail

NAME="Iosevka global"
DRY_RUN=0
EXPORT=""

usage() {
  cat <<'EOF'
usage: sync-stylus.sh [EXPORT.json] [--name NAME] [--dry-run]

  EXPORT.json   Stylus export file. Default: newest ~/Downloads/stylus-*.json
  --name NAME   Style name to read. Default: "Iosevka global"
  --dry-run     Print the result and write nothing
EOF
}

die() {
  printf 'sync-stylus: %s\n' "$1" >&2
  exit 1
}

while [ $# -gt 0 ]; do
  case "$1" in
    --name) [ $# -ge 2 ] || die '--name needs a value'; NAME=$2; shift 2 ;;
    --dry-run) DRY_RUN=1; shift ;;
    -h | --help) usage; exit 0 ;;
    -*) die "unknown flag: $1" ;;
    *) EXPORT=$1; shift ;;
  esac
done

ROOT=$(git rev-parse --show-toplevel 2>/dev/null) || die 'run inside the NixConfig repo'
EXT="$ROOT/dendritic/home-modules/zen-browser/extensions"
[ -d "$EXT" ] || die "missing directory: $EXT"

if [ -z "$EXPORT" ]; then
  # Newest export wins when a run leaves several files behind.
  for f in "$HOME"/Downloads/stylus-*.json; do
    [ -f "$f" ] || continue
    if [ -z "$EXPORT" ] || [ "$f" -nt "$EXPORT" ]; then
      EXPORT=$f
    fi
  done
fi
[ -n "$EXPORT" ] || die 'no export file found. Pass a path or export one from Stylus.'
[ -f "$EXPORT" ] || die "no such file: $EXPORT"

jq -e . "$EXPORT" >/dev/null 2>&1 || die "not valid JSON: $EXPORT"

STYLE=$(jq -e --arg name "$NAME" '
  (if type == "array" then . else [.] end)
  | map(select(type == "object" and .name == $name))
  | if length == 0 then error("no style named " + $name)
    elif length > 1 then error("several styles named " + $name + "; keep one")
    else .[0] end
' "$EXPORT") || die "style lookup failed in $EXPORT"

CODE=$(printf '%s' "$STYLE" | jq -r '
  if (.sections | length) == 0 then error("style has no sections")
  else [.sections[] | .code // ""] | join("\n") end
')

MATCH=$(printf '%s' "$STYLE" | jq '
  def uniq: (. // []) | map(select(. != null and . != "")) | unique;
  {
    domains: [.sections[]? | (.domains // [])[]] | uniq,
    urlPrefixes: [.sections[]? | (.urlPrefixes // [])[]] | uniq,
    urls: [.sections[]? | (.urls // [])[]] | uniq,
    regexps: [.sections[]? | (.regexps // [])[]] | uniq,
    exclusions: (.exclusions | uniq),
    inclusions: (.inclusions | uniq)
  }
')

CSS_OUT="$EXT/stylus.css"
MATCH_OUT="$EXT/stylus-match.json"

if [ "$DRY_RUN" = 1 ]; then
  printf 'style: %s\n' "$NAME"
  printf 'source: %s\n' "$EXPORT"
  printf '%s\n' "$MATCH"
  exit 0
fi

printf '%s\n' "$CODE" >"$CSS_OUT"
printf '%s\n' "$MATCH" >"$MATCH_OUT"

printf 'wrote %s (%s lines)\n' "${CSS_OUT#"$ROOT"/}" "$(wc -l <"$CSS_OUT")"
printf 'wrote %s\n' "${MATCH_OUT#"$ROOT"/}"
printf 'filters: %s\n' "$(printf '%s' "$MATCH" | jq -r '
  [to_entries[] | "\(.key)=\(.value | length)"] | join(" ")' )"
git -C "$ROOT" --no-pager diff --stat -- "$CSS_OUT" "$MATCH_OUT" || true
