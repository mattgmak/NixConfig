{
  perSystem =
    { pkgs, ... }:
    let
      lean-ctx = pkgs.rustPlatform.buildRustPackage rec {
        pname = "lean-ctx";
        version = "3.9.3";

        src = pkgs.lib.cleanSource ../home-modules/pi-coding-agent/extensions/vendor/lean-ctx;

        buildAndTestSubdir = "rust";

        prePatch = ''
          cp ${src}/rust/Cargo.lock Cargo.lock
        '';

        cargoLock.lockFile = "${src}/rust/Cargo.lock";

        # rusqlite 0.40 / libsqlite3-sys 0.38 use cfg_select!, which is still
        # nightly-only on stable rustc for library code; build.rs needs patching.
        RUSTC_BOOTSTRAP = 1;

        # libsqlite3-sys 0.38 uses cfg_select! in build.rs, which is still
        # nightly-only on stable rustc. lean-ctx uses rusqlite's bundled
        # sqlite (no buildtime_bindgen), so the non-bindgen branch suffices.
        preBuild = ''
                    patched=0
                    for build_rs in "$NIX_BUILD_TOP/cargo-vendor-dir"/libsqlite3-sys-*/build.rs; do
                      [ -f "$build_rs" ] || continue
                      patched=1
                      ${pkgs.python3}/bin/python3 - "$build_rs" <<'PY'
          import pathlib, sys
          path = pathlib.Path(sys.argv[1])
          text = path.read_text()
          old = """        cfg_select! {
                      feature = "buildtime_bindgen" => {
                          use super::{bindings, HeaderLocation};
                          let header = HeaderLocation::FromPath(lib_name.to_owned());
                          bindings::write_to_out_dir(header, out_path);
                      }
                      _ => {
                          super::copy_bindings(lib_name, "bindgen_bundled_version", out_path);
                      }
                  }"""
          new = """        if cfg!(feature = "buildtime_bindgen") {
                      use super::{bindings, HeaderLocation};
                      let header = HeaderLocation::FromPath(lib_name.to_owned());
                      bindings::write_to_out_dir(header, out_path);
                  } else {
                      super::copy_bindings(lib_name, "bindgen_bundled_version", out_path);
                  }"""
          if old not in text:
              raise SystemExit(f"libsqlite3-sys patch target not found in {path}")
          path.write_text(text.replace(old, new, 1))
          PY
                    done

                    for lib_rs in "$NIX_BUILD_TOP/cargo-vendor-dir"/rusqlite-*/src/lib.rs; do
                      [ -f "$lib_rs" ] || continue
                      patched=1
                      ${pkgs.python3}/bin/python3 - "$lib_rs" <<'PY'
          import pathlib, sys
          path = pathlib.Path(sys.argv[1])
          text = path.read_text()
          needle = "#![feature(cfg_select)]\n"
          if needle in text:
              raise SystemExit(0)
          marker = "#![cfg_attr(docsrs, feature(doc_cfg))]\n"
          if marker not in text:
              raise SystemExit(f"unexpected rusqlite lib.rs header in {path}")
          path.write_text(text.replace(marker, marker + needle, 1))
          PY
                    done

                    if [ "$patched" -eq 0 ]; then
                      echo "lean-ctx.nix: no libsqlite3-sys/rusqlite sources found under $NIX_BUILD_TOP/cargo-vendor-dir" >&2
                      exit 1
                    fi
        '';

        nativeBuildInputs = with pkgs; [
          cmake
          pkg-config
        ];

        buildInputs = with pkgs; [
          openssl
        ];

        doCheck = false;

        meta = with pkgs.lib; {
          description = "Context Runtime for AI Agents — token compression, cross-session memory, CCP";
          homepage = "https://leanctx.com";
          license = licenses.asl20;
          platforms = platforms.all;
          mainProgram = "lean-ctx";
        };
      };
    in
    {
      packages.lean-ctx = lean-ctx;
    };
}
