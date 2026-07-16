def debug-enabled [] {
  not (($env.GH_DASH_PR_REVIEW_DEBUG? | default "") | is-empty)
}

def debug-hint [] {
  if (debug-enabled) { $" (see @LOGFILE@)" } else { "" }
}

def log [msg: string] {
  if (debug-enabled) {
    let line = $"[(date now | format date '%Y-%m-%d %H:%M:%S%z')] ($msg)\n"
    $line | save -a @LOGFILE@
  }
}

def dir-session-name [path: string, n: int = 2] {
  let parts = ($path | path split | where {|part| not ($part | is-empty)} | reverse | take $n | reverse)
  ($parts | str join "/" | str replace -a "." "_" | str replace -a ":" "_")
}

def tmux-has-session [name: string] {
  (^tmux has-session -t $"=($name)" | complete).exit_code == 0
}

def find-session-by-path [worktree: string] {
  let wt = ($worktree | path expand)
  let sessions_out = (^tmux list-sessions -F '#{session_name}' | complete)
  if $sessions_out.exit_code != 0 {
    log $"list-sessions failed exit=($sessions_out.exit_code) stderr=($sessions_out.stderr)"
    ""
  } else {
    ($sessions_out.stdout
      | lines
      | each {|session|
        let panes_out = (^tmux list-panes -t $"=($session)" -F '#{pane_current_path}' | complete)
        if $panes_out.exit_code != 0 {
          null
        } else {
          let hit = ($panes_out.stdout
            | lines
            | any {|pane_path|
              let pane = ($pane_path | path expand)
              $pane == $wt or ($pane | str starts-with ($wt + "/"))
            })
          if $hit { $session } else { null }
        }
      }
      | compact
      | first
      | default "")
  }
}

def session-matches-worktree [session: string, worktree: string] {
  let wt = ($worktree | path expand)
  let panes_out = (^tmux list-panes -t $"=($session)" -F '#{pane_current_path}' | complete)
  if $panes_out.exit_code != 0 {
    false
  } else {
    $panes_out.stdout
      | lines
      | any {|pane_path|
        let pane = ($pane_path | path expand)
        $pane == $wt or ($pane | str starts-with ($wt + "/"))
      }
  }
}

def session-for-worktree [worktree: string] {
  let by_path = (find-session-by-path $worktree | default "")
  if ($by_path != "") {
    log $"found existing session by path: ($by_path)"
    return $by_path
  }

  let by_name = (dir-session-name $worktree)
  log $"session lookup by_name=($by_name)"
  if (tmux-has-session $by_name) and (session-matches-worktree $by_name $worktree) {
    log $"found existing session by name: ($by_name)"
    $by_name
  } else {
    log "no existing session found"
    ""
  }
}

def connect-review-window [session: string, worktree: string, pr: int] {
  let worktree = ($worktree | path expand)
  let wt_escaped = ($worktree | str replace -a "'" "'\\''")
  let nvim_launch = ("cd '" + $wt_escaped + "' && exec nvim -c ':silent Octo pr edit " + ($pr | into string) + "'")
  log $"creating review window session=($session) worktree=($worktree) pr=($pr)"
  log $"launch cmd: bash -lc ($nvim_launch)"
  let win_out = (^tmux new-window -d -P -t $"=($session)" -n review -c $worktree -F '#{window_index}' bash -lc $nvim_launch | complete)
  log $"new-window exit=($win_out.exit_code) stdout=($win_out.stdout) stderr=($win_out.stderr)"
  if $win_out.exit_code != 0 {
    error make {
      msg: ($"failed to create review window in session ($session): " + $win_out.stderr + (debug-hint))
    }
  }
  let win_index = ($win_out.stdout | str trim)
  let target = $"=($session):($win_index)"
  let switch_out = (^tmux switch-client -t $target | complete)
  log $"switch-client exit=($switch_out.exit_code) stderr=($switch_out.stderr) target=($target)"
  if $switch_out.exit_code != 0 {
    error make {
      msg: ($"failed to switch client to review window ($target): " + $switch_out.stderr + (debug-hint))
    }
  }
  $target
}

def is-repo-path [repo: string] {
  ($repo | str starts-with "/") or ($repo | str starts-with "~") or ($repo | str starts-with ".")
}

def normalize-repo-id [text: string] {
  $text
    | str trim
    | str replace -r '\.git$' ""
    | str replace -r '(?i)^https?://[^/]+/' ""
    | str replace -r '(?i)^git@[^:]+:' ""
    | str downcase
}

def git-origin-matches [path: string, owner_repo: string] {
  let out = (^git -C $path remote get-url origin | complete)
  if $out.exit_code != 0 {
    false
  } else {
    (normalize-repo-id ($out.stdout | str trim)) == (normalize-repo-id $owner_repo)
  }
}

def to-main-repo [path: string] {
  let git_dir = (^git -C $path rev-parse --git-dir | complete)
  if $git_dir.exit_code != 0 {
    return $path
  }
  let gd = ($git_dir.stdout | str trim | path expand)
  if ($gd | str contains "/.git/worktrees/") {
    ($gd | split row "/.git/worktrees/" | get 0)
  } else if ($gd | str ends-with "/.git") {
    ($gd | path dirname)
  } else {
    $path
  }
}

def find-repo-root [owner_repo: string] {
  let owner_repo = ($owner_repo | str trim)
  if (($owner_repo | split row "/" | length) != 2) {
    error make {
      msg: ($"expected owner/repo from gh-dash, got: ($owner_repo)" + (debug-hint))
    }
  }

  let cwd_root = (try {
    let out = (^git rev-parse --show-toplevel | complete)
    if $out.exit_code != 0 {
      null
    } else {
      let root = (to-main-repo ($out.stdout | str trim))
      if (git-origin-matches $root $owner_repo) { $root } else { null }
    }
  } catch {|_| null })

  if ($cwd_root != null) {
    log $"resolved ($owner_repo) via cwd: ($cwd_root)"
    return $cwd_root
  }

  let code_root = ($env.HOME | path join "code")
  if not ($code_root | path exists) {
    error make {
      msg: ("no local clone found for " + $owner_repo + ". Clone it under ~/code first." + (debug-hint))
    }
  }

  let found = (
    glob $"($code_root)/**/.git"
    | each {|git_entry|
        let root = ($git_entry | path dirname)
        if (git-origin-matches $root $owner_repo) {
          to-main-repo $root
        } else {
          null
        }
      }
    | compact
    | uniq
    | first
  )

  if ($found | is-empty) {
    error make {
      msg: ("no local clone found for " + $owner_repo + " under ~/code. Clone it first." + (debug-hint))
    }
  }

  log $"resolved ($owner_repo) via scan: ($found)"
  $found
}

def wt-switch-args [repo: string, pr: int] {
  let repo = ($repo | str trim)
  if (is-repo-path $repo) {
    let expanded = (to-main-repo ($repo | path expand))
    if not ($expanded | path exists) {
      error make {
        msg: ($"repo path does not exist: ($expanded)." + (debug-hint))
      }
    }
    log $"using local repo checkout: ($expanded)"
    ["switch", "-C", $expanded, $"pr:($pr)"]
  } else {
    let repo_root = (find-repo-root $repo)
    ["switch", "-C", $repo_root, $"pr:($pr)"]
  }
}

def worktree-from-wt-output [text: string] {
  let path = ($text | parse -r '@ (?P<path>[^,\n]+)' | get path | first)
  if ($path | is-empty) {
    error make {
      msg: ("could not parse worktree path from wt output" + (debug-hint))
      label: { text: $text }
    }
  }
  $path | path expand
}

def main [repo: string, pr: int] {
  let repo = ($repo | str trim)
  let tmux_env = ($env.TMUX? | default "(unset)")
  log ($"=== start pr=($pr) repo=($repo) tmux=($tmux_env) pwd=" + $env.PWD)

  let wt_args = (wt-switch-args $repo $pr)
  log ($"running: wt " + ($wt_args | str join ' '))

  let wt_out = (^wt ...$wt_args | complete)
  log $"wt exit=($wt_out.exit_code)"
  log $"wt stderr:\n($wt_out.stderr)"
  log $"wt stdout:\n($wt_out.stdout)"

  if $wt_out.exit_code != 0 {
    error make { msg: ($"wt switch failed with exit ($wt_out.exit_code)" + (debug-hint)) }
  }

  let worktree = worktree-from-wt-output $"($wt_out.stderr)($wt_out.stdout)"
  log $"worktree=($worktree)"

  let existing_session = (session-for-worktree $worktree)
  if ($existing_session != "") {
    log $"using existing session=($existing_session)"
    connect-review-window $existing_session $worktree $pr
  } else {
    log $"running: sesh connect --switch ($worktree)"
    let sesh_out = (^sesh connect --switch $worktree | complete)
    log $"sesh exit=($sesh_out.exit_code) stderr=($sesh_out.stderr) stdout=($sesh_out.stdout)"

    if $sesh_out.exit_code != 0 {
      error make {
        msg: ($"sesh connect failed with exit ($sesh_out.exit_code)" + (debug-hint))
      }
    }

    let session = (^tmux display-message -p '#{client_session}')
    log $"client_session after sesh connect=($session)"
    connect-review-window $session $worktree $pr
  }

  log "done"
}
