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
          preview = {
            width = 0.5;
          };
          pager.diff = "diffnav";
        };
      };
      home.packages = with pkgs; [
        diffnav
      ];
    };
}
