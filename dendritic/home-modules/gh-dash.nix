{
  flake.homeModules.gh-dash =
    {
      pkgs,
      lib,
      ...
    }:
    let
      logFile = "/tmp/gh-dash-pr-review.log";

      prReviewNu = pkgs.writeScript "gh-dash-pr-review.nu" ''
        def debug-enabled [] {
          not (($env.GH_DASH_PR_REVIEW_DEBUG? | default "") | is-empty)
        }

        def debug-hint [] {
          if (debug-enabled) { $" (see ${logFile})" } else { "" }
        }

        def log [msg: string] {
          if (debug-enabled) {
            let line = $"[(date now | format date '%Y-%m-%d %H:%M:%S%z')] ($msg)\n"
            $line | save -a ${logFile}
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

        def session-for-worktree [worktree: string] {
          let by_name = (dir-session-name $worktree)
          log $"session lookup by_name=($by_name)"
          if (tmux-has-session $by_name) {
            log $"found existing session by name: ($by_name)"
            $by_name
          } else {
            let by_path = (find-session-by-path $worktree | default "")
            if ($by_path != "") {
              log $"found existing session by path: ($by_path)"
            } else {
              log "no existing session found"
            }
            $by_path
          }
        }

        def connect-review-window [session: string, worktree: string] {
          log $"creating review window session=($session) worktree=($worktree)"
          let win_out = (^tmux new-window -d -P -t $"=($session)" -n review -c $worktree -F '#{window_index}' | complete)
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

        def repo-root [] {
          let result = (^git rev-parse --show-toplevel | complete)
          if $result.exit_code != 0 {
            error make {
              msg: ("not inside a git repo, pwd=" + $env.PWD + ". Start gh dash from your repo checkout." + (debug-hint))
            }
          }
          $result.stdout | str trim
        }

        def worktree-from-wt-output [text: string] {
          let path = ($text | parse -r '@ (?P<path>[^,\n]+)' | get path | first)
          if ($path | is-empty) {
            error make {
              msg: ("could not parse worktree path from wt output" + (debug-hint))
              label: { text: $text }
            }
          }
          $path
        }

        def main [pr: int] {
          let repo_cwd = (repo-root)
          let tmux_env = ($env.TMUX? | default "(unset)")
          log ($"=== start pr=($pr) repo_cwd=($repo_cwd) tmux=($tmux_env) pwd=" + $env.PWD)

          let wt_args = ["switch", "-C", $repo_cwd, $"pr:($pr)"]
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
          let target = if ($existing_session != "") {
            log $"using existing session=($existing_session)"
            connect-review-window $existing_session $worktree
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
            connect-review-window $session $worktree
          }

          let nvim_cmd = $"nvim -c \":silent Octo pr edit ($pr)\""
          log $"send-keys to ($target): ($nvim_cmd)"
          let send_out = (^tmux send-keys -t $target -l $nvim_cmd | complete)
          log $"send-keys exit=($send_out.exit_code) stderr=($send_out.stderr)"
          if $send_out.exit_code != 0 {
            error make {
              msg: ($"tmux send-keys failed: " + $send_out.stderr + (debug-hint))
            }
          }
          ^tmux send-keys -t $target Enter
          log "done"
        }
      '';

      gh-dash-pr-review = pkgs.writeShellScriptBin "gh-dash-pr-review" ''
        set -euo pipefail
        pr="''${1:?usage: gh-dash-pr-review <pr-number>}"
        args=("${lib.getExe pkgs.nushell}" ${prReviewNu} "$pr")
        run() {
          if [ -n "''${TMUX:-}" ]; then
            ${lib.getExe pkgs.tmux} run-shell "$(printf '%q ' "''${args[@]}")"
          else
            "''${args[@]}"
          fi
        }
        if [ -n "''${GH_DASH_PR_REVIEW_DEBUG:-}" ]; then
          {
            echo "[$(date -Iseconds)] wrapper tmux=''${TMUX:-} pwd=$PWD pr=$pr"
            echo "[$(date -Iseconds)] wrapper cmd: ''${args[*]}"
          } >> ${logFile}
          if ! run 2>>${logFile}; then
            echo "[$(date -Iseconds)] nu failed exit=$?" >> ${logFile}
            exit 1
          fi
        else
          run
        fi
      '';
    in
    {
      programs.gh-dash = {
        enable = true;
        settings = {
          prSections = [
            {
              title = "My Pull Requests";
              filters = "is:open author:@me";
            }
            {
              title = "Needs My Review";
              filters = "is:open review-requested:@me";
            }
            {
              title = "Involved";
              filters = "is:open involves:@me -author:@me";
            }
          ];
          defaults = {
            issuesLimit = 20;
            notificationsLimit = 20;
            prApproveComment = "Looks good";
            preview = {
              open = true;
              width = 100;
            };
            prsLimit = 20;
            refetchIntervalMinutes = 30;
          };
          confirmQuit = true;
          pager.diff = "diffnav";
          keybindings = {
            prs = [
              {
                key = "C";
                name = "Code Review";
                command = "gh-dash-pr-review {{.PrNumber}}";
              }
            ];
          };
        };
      };
      home.packages = with pkgs; [
        diffnav
        gh-dash-pr-review
      ];
    };
}
