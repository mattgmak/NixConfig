{ hostname, ... }: {
  programs.git = {
    enable = true;
    delta = { enable = true; };
    userName = "mattgmak";
    userEmail = "u3592095@connect.hku.hk";
    extraConfig = {
      fetch.prune = true;
      rerere.enabled = true;
      # 7 days
      # credential.helper = [ "cache --timeout 604800" "oauth" ];
      # credential = {
      # helper = "manager";
      # "https://github.com".username = "mattgmak";
      # credentialStore = "cache";
      # cacheOptions = "--timeout 604800";
      # };
    } // (if hostname == "GoofyWSL" then {
      credential.helper =
        "/mnt/c/Program\\ Files/Git/mingw64/bin/git-credential-manager.exe";
    } else
      { });
  };
  programs.gh = {
    enable = true;
    hosts = {
      "github.com" = {
        git_protocol = "https";
        users = { mattgmak = { user = "mattgmak"; }; };
      };
    };
    settings = {
      # The current version of the config schema
      version = 1;
      # What protocol to use when performing git operations. Supported values: ssh, https
      git_protocol = "https";
      # What editor gh should run when creating issues, pull requests, etc. If blank, will refer to environment.
      editor = "";
      # When to interactively prompt. This is a global config that cannot be overridden by hostname. Supported values: enabled, disabled
      prompt = "enabled";
      # Preference for editor-based interactive prompting. This is a global config that cannot be overridden by hostname. Supported values: enabled, disabled
      prefer_editor_prompt = "disabled";
      # A pager program to send command output to, e.g. "less". If blank, will refer to environment. Set the value to "cat" to disable the pager.
      pager = "";
      # Aliases allow you to create nicknames for gh commands
      aliases = { co = "pr checkout"; };
      # The path to a unix socket through which send HTTP connections. If blank, HTTP traffic will be handled by net/http.DefaultTransport.
      http_unix_socket = "";
      # What web browser gh should use when opening URLs. If blank, will refer to environment.
      browser = "";
      # Whether to display labels using their RGB hex color codes in terminals that support truecolor. Supported values: enabled, disabled
      color_labels = "disabled";
      # Whether customizable, 4-bit accessible colors should be used. Supported values: enabled, disabled
      accessible_colors = "disabled";
      # Whether an accessible prompter should be used. Supported values: enabled, disabled
      accessible_prompter = "disabled";
      # Whether to use a animated spinner as a progress indicator. If disabled, a textual progress indicator is used instead. Supported values: enabled, disabled
      spinner = "enabled";

    };
  };
}
