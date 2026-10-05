# Android tooling dev shell (adb/fastboot tooling + payload dumper):
# `nix develop ~/NixConfig#android`. Folded in from the former standalone dev-shells/android flake.
{
  perSystem =
    { pkgs, system, ... }:
    # Plain Nix `if`, not lib.mkIf: flake-parts does not unwrap mkIf, and a bare
    # mkIf at the perSystem root would register `_type`/`_then` as option names.
    if system != "x86_64-linux" then
      { }
    else
      {
        devShells.android = pkgs.mkShell {
          packages = with pkgs; [
            android-tools
            payload-dumper-go
          ];
        };
      };
}
