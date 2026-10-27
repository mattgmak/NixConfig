{ inputs, ... }:
{
  flake.homeModules.worktrunk =
    { pkgs, ... }:
    {
      programs.worktrunk = {
        enable = true;
        # HM core now ships programs.worktrunk. Keep the pinned flake binary.
        package = inputs.worktrunk.packages.${pkgs.stdenv.hostPlatform.system}.worktrunk;
        enableNushellIntegration = true;
      };
      home.file.".config/worktrunk/config.toml".text = ''
        # toml
        [post-start]
        copy = "{% if base %}wt step copy-ignored --from {{ base }}{% else %}wt step copy-ignored{% endif %}"

        [post-switch]
        copy-pwd = "printf %s {{ worktree_path }} | ${
          if pkgs.stdenv.hostPlatform.isDarwin then "/usr/bin/pbcopy" else "${pkgs.wl-clipboard}/bin/wl-copy"
        }"
      '';
    };
}
