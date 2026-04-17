{ inputs, ... }:
{
  flake.homeModules.worktrunk =
    { pkgs, ... }:
    {
      imports = [ inputs.worktrunk.homeModules.default ];
      programs.worktrunk = {
        enable = true;
        enableNushellIntegration = true;
      };
      home.file.".config/worktrunk/config.toml".text = ''
        # toml
        [post-start]
        copy = "{% if base %}wt step copy-ignored --from {{ base }}{% else %}wt step copy-ignored{% endif %}"

        [post-switch]
        copy-pwd = "printf %s {{ worktree_path }} | ${
          if pkgs.stdenv.isDarwin then "/usr/bin/pbcopy" else "${pkgs.wl-clipboard}/bin/wl-copy"
        }"
      '';
    };
}
