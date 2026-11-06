#!/bin/sh
# Clean up submodules that a commit removed. Git drops the index entry but leaves the
# worktree behind, so it shows up as an untracked directory. This also removes the
# gitdir under .git/modules, the submodule.<name> sections left by renames, and the
# empty owner directories. post-merge and post-checkout call it; -n only reports.
#
# A rename leaves residue that .git/config alone cannot find: a gitdir with no section
# left behind, and an old checkout whose .git file still names the old gitdir. So the
# targets come from three sources: every gitdir under .git/modules, every config
# section, and every untracked directory that holds a nested .git file.
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
tab=$(printf '\t')

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
# Normalized absolute path of a directory; empty when it does not exist.
absdir() {
  if [ -d "$1" ]; then
    (cd -- "$1" && pwd -P) 2>/dev/null || true
  fi
}
# Absolute worktree a submodule gitdir serves, from its own core.worktree. The path is
# full of ../ hops, so it has to be normalized before it can be compared to $root.
worktree_of() {
  value=$(git config -f "$1/config" --get core.worktree 2>/dev/null || true)
  [ -n "$value" ] || return 0
  case $value in
  /*) absdir "$value" ;;
  *) absdir "$1/$value" ;;
  esac
}
# Gitdir a directory's .git file points at, resolved; empty when it is unreadable.
linked_gitdir() {
  if [ -f "$1/.git" ]; then
    git -C "$1" rev-parse --absolute-git-dir 2>/dev/null || true
  fi
}
# The checkout a gitdir serves, empty when the gitdir serves nothing it owns.
owned_checkout() {
  work=$(worktree_of "$1")
  case $work in
  "$root"/*) ;;
  *) return 0 ;;
  esac
  [ -f "$work/.git" ] || return 0
  [ "$(linked_gitdir "$work")" = "$1" ] || return 0
  printf '%s\n' "$work"
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
# True when an ancestor of $1 under .git/modules is itself a gitdir. Empty dirs inside
# a gitdir (refs/tags, rr-cache) belong to git, not to a leftover owner directory.
under_gitdir() {
  p=$(dirname "$1")
  while [ "$p" != "$modules" ] && [ "$p" != / ]; do
    if [ -f "$p/HEAD" ] && [ -d "$p/objects" ]; then
      return 0
    fi
    p=$(dirname "$p")
  done
  return 1
}

live=$(sections .gitmodules)
configs=$common/config
if [ "$gitdir" != "$common" ] && [ -f "$gitdir/config" ]; then
  configs=$(printf '%s\n%s\n' "$configs" "$gitdir/config")
fi

# Targets are "kind<TAB>path" lines, deduplicated. kind G is a gitdir, W a worktree
# checkout, S a config section.
targets=$(
  {
    # Gitdirs and their checkouts, at any depth, so a renamed name still shows up.
    find "$modules" -mindepth 1 -maxdepth 8 -type d 2>/dev/null |
      while IFS= read -r d; do
        if [ ! -f "$d/HEAD" ] || [ ! -d "$d/objects" ]; then
          continue
        fi
        if listed "${d#"$modules"/}"; then
          continue
        fi
        owned=$(owned_checkout "$d")
        # A tracked checkout that still points at this gitdir keeps it alive under the
        # old name, even though .gitmodules renamed it. Only the section is stale.
        if [ -n "$owned" ] && tracked "${owned#"$root"/}"; then
          continue
        fi
        printf 'G%s%s\n' "$tab" "$d"
        [ -n "$owned" ] && printf 'W%s%s\n' "$tab" "$owned"
      done
    # Config sections for names that .gitmodules no longer lists.
    printf '%s\n' "$configs" | while IFS= read -r file; do
      sections "$file" | while IFS= read -r name; do
        if ! listed "$name"; then
          printf 'S%s%s%s%s\n' "$tab" "$file" "$tab" "$name"
        fi
      done
    done
    # Untracked directories that hold a nested repo. git clean -d skips those, so a
    # checkout survives even after its gitdir is gone.
    git status --porcelain --untracked-files=normal --ignore-submodules=all . 2>/dev/null |
      sed -n 's/^?? //p' |
      while IFS= read -r entry; do
        path=$(absdir "${entry%/}")
        [ -n "$path" ] || continue
        if [ -f "$path/.git" ]; then
          tracked "$path" || printf 'W%s%s\n' "$tab" "$path"
          continue
        fi
        find "$path" -mindepth 2 -maxdepth 2 -name .git -type f 2>/dev/null |
          while IFS= read -r f; do
            child=$(absdir "${f%/.git}")
            [ -n "$child" ] || continue
            tracked "$child" || printf 'W%s%s\n' "$tab" "$child"
          done
      done
  } | sort -u
)

printf '%s\n' "$targets" | while IFS=$tab read -r kind path extra; do
  case $kind in
  G)
    drop "$path"
    prune "$path"
    ;;
  W)
    [ -d "$path" ] || continue
    drop "$path"
    prune "$path"
    ;;
  S)
    [ -n "$dry" ] || git config --file "$path" --remove-section "submodule.$extra"
    say "submodule.$extra from ${path#"$common"/}"
    ;;
  esac
done

# Empty owner directories left behind under .git/modules.
find "$modules" -mindepth 1 -type d -empty 2>/dev/null |
  while IFS= read -r d; do
    under_gitdir "$d" && continue
    drop "$d"
  done
