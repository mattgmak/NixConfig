{ inputs, ... }:
{
  flake.nixosModules.orca-slicer =
    { pkgs, lib, ... }:
    let
      wxInspectorSrc = pkgs.fetchzip {
        url = "https://github.com/Noisyfox/wxInspector/archive/refs/tags/v1.0.0.zip";
        hash = "sha256-AQbV2vAGJXatAXwLAxhWVXTdKqxj2v0THexQyKbroJw=";
      };

      nightlyPkg = inputs.orca-slicer-nightly.packages.${pkgs.stdenv.hostPlatform.system}.default;
      orca-slicer = nightlyPkg.overrideAttrs (oldAttrs: let
        wxWidgets =
          lib.head (lib.filter (drv: lib.hasInfix "wxwidgets" (drv.pname or drv.name or "")) (
            oldAttrs.nativeBuildInputs or [ ]
          ));
      in {
        nativeBuildInputs = (oldAttrs.nativeBuildInputs or [ ]) ++ [ pkgs.python312 ];
        buildInputs = (oldAttrs.buildInputs or [ ]) ++ [
          pkgs.python312
          pkgs.assimp
        ];
        cmakeFlags = (oldAttrs.cmakeFlags or [ ]) ++ [
          # Nightly bundles SLVS + OCCT ModelingAlgorithms for the Design/CAD tab; nixpkgs
          # recipe doesn't build those deps. Slicer/AMS path doesn't need parametric CAD.
          "-DSLIC3R_CAD=OFF"
        ];
        preConfigure =
          (oldAttrs.preConfigure or "")
          + ''
            wxInspectorPrefix="$PWD/.wxinspector"
            cmake -S "${wxInspectorSrc}" -B "$TMPDIR/wxinspector-build" \
              -DCMAKE_INSTALL_PREFIX="$wxInspectorPrefix" \
              -DCMAKE_BUILD_TYPE=Release \
              -DwxWidgets_CONFIG_EXECUTABLE=${wxWidgets}/bin/wx-config \
              -DwxWidgets_CONFIG_OPTIONS=--toolkit=gtk3 \
              -DCMAKE_CXX_FLAGS="-DwxDEBUG_LEVEL=0" \
              -DCMAKE_POSITION_INDEPENDENT_CODE=ON
            cmake --build "$TMPDIR/wxinspector-build" -j$NIX_BUILD_CORES
            cmake --install "$TMPDIR/wxinspector-build"
            cmakeFlags+=("-DwxInspector_DIR=$wxInspectorPrefix/lib64/cmake/wxInspector")
            export NIX_CFLAGS_COMPILE="$NIX_CFLAGS_COMPILE -I$wxInspectorPrefix/include"
          '';
        patches =
          (builtins.filter (p: !(lib.hasInfix "opencv-nix" (toString p))) (oldAttrs.patches or [ ]))
          ++ [
            ./patches/orca-slicer-opencv-nix.patch
            ./patches/orca-slicer-nix-python.patch
            ./patches/orca-slicer-skip-bundled-ffmpeg-copy.patch
            ./patches/orca-slicer-skip-bundled-ffmpeg-install.patch
            ./patches/orca-slicer-skip-bundled-ffmpeg-install-src.patch
            ./patches/orca-slicer-skip-bundled-python-copy-linux.patch
          ];
      });
    in
    {
      environment.systemPackages = [
        orca-slicer
        pkgs.nanum # for fixing https://github.com/OrcaSlicer/OrcaSlicer/issues/11641
      ];
    };
}
