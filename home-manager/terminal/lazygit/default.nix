{ ... }: {
  programs.lazygit = {
    enable = true;
    settings = {
      keybinding = {
        universal = {
          nextItem-alt = "k";
          prevItem-alt = "j";
          prevBlock-alt = "l";
          nextBlock-alt = ";";
          scrollDownMain-alt1 = "K";
          scrollUpMain-alt1 = "J";
          scrollLeft = "L";
          scrollRight = ":";
          executeShellCommand = "h";
        };
      };
      gui = { scrollHeight = 10; };
      git = {
        paging = {
          colorArg = "always";
          pager =
            "delta --paging=never --line-numbers --hunk-header-style=omit";
        };
      };
    };
  };

}
