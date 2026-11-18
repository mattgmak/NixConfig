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
      let
        # nixpkgs caps android-tools at 37.0.0p1; the Full OTA Zip method names v37.0.3.
        # Vendored Google canary binary, scoped to this shell only, no overlay.
        android-tools-37_0_3 = pkgs.stdenv.mkDerivation {
          pname = "android-tools";
          version = "37.0.3";
          src = pkgs.fetchzip {
            url = "https://dl.google.com/android/repository/platform-tools_r37.0.3-linux.zip";
            hash = "sha256-xMToYp3+ifHG+/yR3BcG+PVC+KbomVm6fj6G0y4Fwhg=";
          };
          nativeBuildInputs = [ pkgs.autoPatchelfHook ];
          installPhase = ''
            runHook preInstall
            mkdir -p $out/bin $out/lib $out/share/mke2fs
            for b in adb fastboot etc1tool hprof-conv make_f2fs make_f2fs_casefold mke2fs sqlite3; do
              install -Dm755 $src/$b $out/bin/$b
            done
            cp -r $src/lib64/. $out/lib/
            install -m644 $src/mke2fs.conf $out/share/mke2fs/mke2fs.conf
            runHook postInstall
          '';
        };
      in
        {
          devShells.android = pkgs.mkShell {
            packages = [
              android-tools-37_0_3
              pkgs.payload-dumper-go
            ];
          };
        };
}
