#!/bin/sh
# Clean up submodules that a commit removed. Git drops the index entry but leaves the
# worktree behind, so it shows up as an untracked directory. This also removes the
# gitdir under .git/modules, the submodule.<name> sections left by renames, and the
# empty owner directories. post-merge and post-checkout call it; -n only reports.
set -eu

root=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
cd "$root"
[ -f .gitmodules ] || exit 0
gitdir=$(cd "$(git rev-parse --git-dir)" && pwd -P)
common=$(cd "$(git rev-parse --git-common-dir)" && pwd -P)
modules=$gitdir/modules
[ -d "$modules" ] || exit 0

dry=""
case ${1:-} in
-n | --dry-run) dry=1 ;;
esac

say() {
  if [ -n "$dry" ]; then
    printf 'submodule-clean: would remove %s\n' "$1"
  else
    printf 'submodule-clean: removed %s\n' "$1"
  fi
}
drop() {
  [ -n "$dry" ] || rm -rf -- "$1"
  say "$1"
}
# Section names in a git config file.
sections() { sed -n 's/^\[submodule "\(.*\)"\]$/\1/p' "$1" 2>/dev/null || true; }
tracked() { git ls-files --error-unmatch -- "$1" >/dev/null 2>&1; }
listed() { printf '%s\n' "$live" | grep -Fxq -- "$1"; }

# Absolute worktree path a submodule gitdir serves, from its own core.worktree.
worktree_of() {
  value=$(git config -f "$1/config" --get core.worktree 2>/dev/null || true)
  [ -n "$value" ] || return 1
  case $value in
  /*) printf '%s\n' "$value" ;;
  *) printf '%s/%s\n' "$(cd "$1" && pwd -P)" "$value" ;;
  esac
}

# Remove directories a deletion left empty, up to but not including the root.
prune() {
  parent=$(dirname "$1")
  while [ "$parent" != "$root" ] && [ "$parent" != / ] && [ -d "$parent" ]; do
    if [ -n "$(ls -A "$parent" 2>/dev/null)" ]; then
      return 0
    fi
    drop "$parent"
    parent=$(dirname "$parent")
  done
}

# Local config files: the shared one plus this worktree's own.
configs=$common/config
if [ "$gitdir" != "$common" ] && [ -f "$gitdir/config" ]; then
  configs=$(printf '%s\n%s\n' "$configs" "$gitdir/config")
fi
live=$(sections .gitmodules)
known=$(
  {
    printf '%s\n' "$configs" | while IFS= read -r file; do sections "$file"; done
  } | sort -u
)

printf '%s\n' "$known" | while IFS= read -r name; do
  [ -n "$name" ] || continue
  if listed "$name"; then
    continue
  fi
  dir=$modules/$name
  if [ -d "$dir" ]; then
    work=$(worktree_of "$dir") || work=""
    if [ -n "$work" ] && [ -d "$work" ]; then
      [ -f "$work/.git" ] || continue
      work=$(cd "$work" && pwd -P)
      case $work in
      "$root"/*) ;;
      *) continue ;;
      esac
      if tracked "${work#"$root"/}"; then
        continue
      fi
      drop "$work"
      prune "$work"
    fi
    drop "$dir"
  fi
  printf '%s\n' "$configs" | while IFS= read -r file; do
    sections "$file" | grep -Fxq -- "$name" || continue
    [ -n "$dry" ] || git config --file "$file" --remove-section "submodule.$name"
    say "submodule.$name from ${file#"$common"/}"
  done
done
