{ inputs, ... }:
{
  perSystem =
    { system, ... }:
    {
      common-overlays = [
        (_: _: {
          ghostty = inputs.ghostty.packages.${system}.default;
        })
        (_final: super: {
          direnv = super.direnv.overrideAttrs (_: {
            doCheck = false;
          });
        })
        inputs.nix4vscode.overlays.default
        inputs.coding-agents.overlays.default
        (_final: prev: {
          # coding-agents replaces package-lock with package-lock.generated.json, which omits
          # @vitest/coverage-v8 (agent devDep); offline npm install then errors ENOTCACHED.
          # overrideAttrs alone does not rebuild npmDeps (still uses old lockfile); override both.
          pi-coding-agent = prev.pi-coding-agent.overrideAttrs (
            old:
            let
              modelsPatch = ''
                cp ${inputs.coding-agents}/packages/pi-coding-agent/models.generated.ts packages/ai/src/models.generated.ts
              '';
            in
            {
              postPatch = modelsPatch;
              npmDeps = prev.fetchNpmDeps {
                inherit (old) src;
                srcs = old.srcs or null;
                sourceRoot = old.sourceRoot or null;
                prePatch = old.prePatch or "";
                patches = old.patches or [ ];
                patchFlags = old.patchFlags or [ ];
                name = "${old.pname}-${old.version}-npm-deps";
                fetcherVersion = 2;
                hash = "sha256-vQdV59PAzY1DzGoaNYBXS+3fhqM6yCJ6YzTmr7nuQmk=";
                postPatch = modelsPatch;
              };
              npmDepsHash = "sha256-vQdV59PAzY1DzGoaNYBXS+3fhqM6yCJ6YzTmr7nuQmk=";
            }
          );
        })
      ];

      common-nixpkgs-config = {
        allowUnfree = true;
      };
    };
}
