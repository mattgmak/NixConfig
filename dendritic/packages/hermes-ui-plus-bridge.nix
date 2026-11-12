# The Hermes UI+ (HUI+) bridge CLI from github.com/robbyczgw-cla/hermes-ui-plus.
# dendritic/nixos-modules/hermes.nix runs one unit per Hermes tenant and installs
# the bundled skill for both.
#
# The npm tarball is the src because it carries bin/ and src/ plus the bundled
# skill/hermes-ui/ tree.
#
# The published tarball ships no package-lock.json, so the lockfile comes from the
# v0.3.1 tag of the source repo and is dropped into the source tree in postPatch,
# where the deps fetch and the build both see it.
{ self, ... }:
{
  perSystem =
    { pkgs, system, ... }:
    {
      packages.hermesUiPlusBridge = pkgs.buildNpmPackage {
        pname = "hermes-ui-plus-bridge";
        version = "0.3.1";

        src = pkgs.fetchurl {
          url = "https://registry.npmjs.org/hermes-ui-plus-bridge/-/hermes-ui-plus-bridge-0.3.1.tgz";
          sha256 = "sha256-DjZbWRojkgr9oyLLeaKT6Mct4Uh/mwqEG6Rv1+bJahc=";
        };

        postPatch = ''
          cp ${pkgs.fetchurl {
            url = "https://raw.githubusercontent.com/robbyczgw-cla/hermes-ui-plus/v0.3.1/bridge/package-lock.json";
            sha256 = "sha256-NcDk4TXqnqwrbaarw+wgsXKJm5Qlqd08wlBTY93jo2g=";
          }} package-lock.json
        '';

        npmDepsHash = "sha256-dNla2H7ZcbuDHohujJWwGrN5sew6ucGAj26aanCaMPo=";

        # Pure JS: the tarball ships no build script, so skip `npm run build`.
        dontNpmBuild = true;

        # The tarball's prepack script runs scripts/bundle-skill.mjs, which the
        # published files list omits. The skill/ tree is already bundled, so the
        # pack step runs with scripts off.
        npmPackFlags = [ "--ignore-scripts" ];
      };
    };
}
