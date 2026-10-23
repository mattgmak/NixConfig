{
  inputs,
  ...
}:
{
  perSystem =
    { system, ... }:
    let
      # Unoverlaid nixpkgs: the node-bin overlay points at these derivations, so
      # building them from the overlaid pkgs would recurse back into the overlay.
      pkgs = import inputs.nixpkgs { inherit system; };

      # TODO: drop this file once nixpkgs ships node 24.22.1 and 22.23.4 in the
      # binary cache. Node 24.18.0 embeds the revoked emSign ECC Root CA - G3.
      # It refuses only while a CA variable is set, so it fails open.
      # The first fixed releases are 24.22.1 and 22.23.4.
      mkNode =
        version: hashes:
        pkgs.callPackage (
          {
            lib,
            stdenv,
            stdenvNoCC,
            fetchurl,
            autoPatchelfHook,
          }:
          let
            srcs = {
              aarch64-darwin = {
                url = "https://nodejs.org/dist/v${version}/node-v${version}-darwin-arm64.tar.gz";
                hash = hashes.aarch64-darwin;
              };
              x86_64-linux = {
                url = "https://nodejs.org/dist/v${version}/node-v${version}-linux-x64.tar.gz";
                hash = hashes.x86_64-linux;
              };
            };
            src =
              srcs.${stdenv.hostPlatform.system}
                or (throw "node ${version}: no upstream tarball for ${stdenv.hostPlatform.system}");
          in
          stdenvNoCC.mkDerivation {
            pname = "node";
            inherit version;

            src = fetchurl {
              inherit (src) url hash;
            };

            # The linux build is a PIE that wants libgcc_s.
            # The darwin build is a plain Mach-O and needs no patching.
            nativeBuildInputs = lib.optionals stdenv.hostPlatform.isLinux [ autoPatchelfHook ];
            buildInputs = lib.optionals stdenv.hostPlatform.isLinux [ stdenv.cc.cc.lib ];

            dontConfigure = true;
            dontBuild = true;

            # Keep the tarball layout. bin/node finds lib/ and share/ in place,
            # and bin/npm stays a symlink into lib/node_modules/npm.
            # The top-level LICENSE and README collide in buildEnv with the go-bin
            # package. Move them out of $out's root. bin/node does not need them.
            installPhase = ''
              runHook preInstall
              mkdir -p $out
              cp -a . $out/
              install -d $out/share/licenses/node $out/share/doc/node
              mv $out/LICENSE $out/share/licenses/node/
              mv $out/README.md $out/CHANGELOG.md $out/share/doc/node/
              runHook postInstall
            '';

            meta = {
              description = "Event-driven JavaScript runtime, prebuilt upstream binary";
              homepage = "https://nodejs.org";
              license = lib.licenses.mit;
              mainProgram = "node";
              sourceProvenance = [ lib.sourceTypes.binaryNativeCode ];
              platforms = builtins.attrNames srcs;
            };
          }
        ) { };
    in
    {
      packages.node-bin = mkNode "24.22.1" {
        aarch64-darwin = "sha256-icaCWT12zUQjP6U7FWMmTn3py7GJytFpE1xbT637wKc=";
        x86_64-linux = "sha256-62co53xXajUWLBIsRcyt8iTYn/AKvI2uRswol8YALXw=";
      };
      packages.node22-bin = mkNode "22.23.4" {
        aarch64-darwin = "sha256-yeHbx0izPtLRT0JEUZHsrxTFYlnHqaJtAELEnsK2ZCg=";
        x86_64-linux = "sha256-uEkihMdqVLr1jWFmjdDkHuD8mK2r+VA9MPBdCPVbRAY=";
      };
    };
}
