{
  flake.homeModules.gh-dash =
    { pkgs, ... }:
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
                command = "tmux new-window -n 'PR-{{.PrNumber}}' 'nu -e `wt switch pr:{{.PrNumber}}; ^pwd | str trim | ${
                  if pkgs.stdenv.isDarwin then "pbcopy" else "wl-copy"
                }`'";
              }
            ];
          };
        };
      };
      home.packages = with pkgs; [
        diffnav
      ];
    };
}
