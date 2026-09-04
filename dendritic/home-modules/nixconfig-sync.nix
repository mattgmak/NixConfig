# NixConfig auto-pull for a user's ~/NixConfig.
#
# Locked behavior (GOOFEUS-AGENT-WORKSPACE.md):
# - `main` branch is the flake SSOT for rebuilds.
# - Agency work happens in git worktrees (worktrunk), NOT on main.
# - On every `home-manager switch`:
#     1. clone --recurse-submodules if ~/NixConfig/.git missing
#     2. git fetch origin, fast-forward main (if not dirty)
#     3. git submodule update --init --recursive
# - Never auto-push. Never touch worktrees. Never force anything.
{
  ...
}:
{
  flake.homeModules.nixconfig-sync =
    {
      lib,
      config,
      pkgs,
      ...
    }:
    let
      repoUrl = "https://github.com/mattgmak/NixConfig";
      mainBranch = "main";
      repoDir = "${config.home.homeDirectory}/NixConfig";
      git = lib.getExe pkgs.git;
    in
    {
      options.tools.nixconfigSync = {
        enable = lib.mkEnableOption "auto-pull ~/NixConfig on HM switch";
        url = lib.mkOption {
          type = lib.types.str;
          default = repoUrl;
        };
      };

      config = lib.mkIf config.tools.nixconfigSync.enable {
        home.activation.ensureNixConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          run() {
            if [ ! -d "${repoDir}/.git" ]; then
              echo "nixconfig-sync: cloning ${repoUrl} → ${repoDir}"
              ${
                lib.getExe pkgs.git
              } clone --recurse-submodules -b ${mainBranch} "${repoUrl}" "${repoDir}"
            else
              echo "nixconfig-sync: fast-forward main in ${repoDir}"
              # fetch + ff main (no-op if dirty/diverged; never force)
              ${git} -C "${repoDir}" fetch origin ${mainBranch}
              ${git} -C "${repoDir}" merge --ff-only origin/${mainBranch} || true
              ${git} -C "${repoDir}" submodule update --init --recursive || true
            fi
          }
          run
        '';
      };
    };
}