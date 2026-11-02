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
        # The body must not define a shell function named `run`: the activation
        # script runs entries in one shell, so the definition would shadow Home
        # Manager's `run` runner for every later entry and swallow their commands.
        home.activation.ensureNixConfig = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
          if [ ! -d "${repoDir}/.git" ]; then
            echo "nixconfig-sync: cloning ${repoUrl} → ${repoDir}"
            ${
              lib.getExe pkgs.git
            } clone --recurse-submodules -b ${mainBranch} "${repoUrl}" "${repoDir}"
          else
            echo "nixconfig-sync: fast-forward main in ${repoDir}"
            # fetch + ff main (no-op if dirty/diverged; never force).
            # A network blip must not abort the whole activation: unbound or
            # tailscale can be down mid-switch, so warn and skip.
            if ${git} -C "${repoDir}" fetch origin ${mainBranch}; then
              ${git} -C "${repoDir}" merge --ff-only origin/${mainBranch} || true
            else
              echo "nixconfig-sync: fetch failed, keep the current tree"
            fi
            # A pull can record a new vendor submodule as an empty dir, and Nix
            # then fails with "Failed to fetch git repository". Init after any
            # pull, even when the fetch above failed.
            ${git} -C "${repoDir}" submodule update --init --recursive || true
          fi
        '';
      };
    };
}