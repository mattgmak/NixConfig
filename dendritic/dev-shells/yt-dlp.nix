# yt-dlp sync support shell (mutagen drives the sync):
# `nix develop ~/NixConfig#yt-dlp`. Folded in from the former standalone dev-shells/yt-dlp flake.
#
# The old flake set `config.allowUnfree = true`; dropped because mutagen is free, so the
# flag was a no-op and perSystem `pkgs` carries no nixpkgs.config.
{
  perSystem =
    { pkgs, system, ... }:
    # Plain Nix `if`, not lib.mkIf: flake-parts does not unwrap mkIf, and a bare
    # mkIf at the perSystem root would register `_type`/`_then` as option names.
    if !(builtins.elem system [ "x86_64-linux" "aarch64-darwin" ]) then
      { }
    else
      {
        devShells.yt-dlp = pkgs.mkShell {
          packages = with pkgs; [ python313Packages.mutagen ];
        };
      };
}
