{
  flake.homeModules.gh-dash =
    {
      pkgs,
      lib,
      ...
    }:
    let
      logFile = "/tmp/gh-dash-pr-review.log";

      prReviewNu = pkgs.writeScript "gh-dash-pr-review.nu" (
        lib.replaceStrings [ "@LOGFILE@" ] [ logFile ] (builtins.readFile ./gh-dash-pr-review.nu)
      );

      gh-dash-pr-review = pkgs.writeShellScriptBin "gh-dash-pr-review" ''
        set -euo pipefail
        repo="''${1:?usage: gh-dash-pr-review <owner/repo> <pr-number>}"
        pr="''${2:?usage: gh-dash-pr-review <owner/repo> <pr-number>}"
        args=("${lib.getExe pkgs.nushell}" ${prReviewNu} "$repo" "$pr")
        run() {
          if [ -n "''${TMUX:-}" ]; then
            local tmux_cmd=""
            if [ -n "''${GH_DASH_PR_REVIEW_DEBUG:-}" ]; then
              tmux_cmd="GH_DASH_PR_REVIEW_DEBUG=''${GH_DASH_PR_REVIEW_DEBUG} "
            fi
            tmux_cmd="$tmux_cmd$(printf '%q ' "''${args[@]}")"
            ${lib.getExe pkgs.tmux} run-shell "$tmux_cmd"
          else
            "''${args[@]}"
          fi
        }
        if [ -n "''${GH_DASH_PR_REVIEW_DEBUG:-}" ]; then
          {
            echo "[$(date -Iseconds)] wrapper tmux=''${TMUX:-} pwd=$PWD repo=$repo pr=$pr"
            echo "[$(date -Iseconds)] wrapper cmd: ''${args[*]}"
          } >> ${logFile}
          run 2>>${logFile}
          ec=$?
          if [ "$ec" -ne 0 ]; then
            echo "[$(date -Iseconds)] nu failed exit=$ec" >> ${logFile}
            exit "$ec"
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
                command = "gh-dash-pr-review '{{.RepoName}}' {{.PrNumber}}";
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
