# agent-browser 0.34.0 — pi-agent-browser-native pins this exact upstream version.
# Based on nixpkgs pkgs/by-name/ag/agent-browser/package.nix (0.27.0).
{ ... }:
{
  flake.agentBrowser034Overlay =
    final: prev:
    let
      pnpm = prev.pnpm_11 or prev.pnpm_10;
      version = "0.34.0";

      src = prev.fetchFromGitHub {
        owner = "vercel-labs";
        repo = "agent-browser";
        tag = "v${version}";
        hash = "sha256-UdCBSe7w0ZgJimB7ixGcaabJjH3m6O0vB1SV9n9apfE=";
      };

      dashboard = prev.stdenv.mkDerivation {
        pname = "agent-browser-dashboard";
        inherit version src;

        nativeBuildInputs = [
          prev.nodejs
          pnpm
          prev.pnpmConfigHook
        ];

        __darwinAllowLocalNetworking = true;

        pnpmDeps = prev.fetchPnpmDeps {
          pname = "agent-browser-dashboard";
          inherit version src pnpm;
          pnpmWorkspaces = [ "dashboard" ];
          fetcherVersion = 4;
          hash = "sha256-tkEhkGO5/JTkzySDEsTmjr5+SEXzk8V0217iQhFhfCw=";
        };

        pnpmWorkspaces = [ "dashboard" ];

        postPatch = ''
          substituteInPlace packages/dashboard/src/app/layout.tsx --replace-fail \
            '{ Geist } from "next/font/google"' \
            'localFont from "next/font/local"'

          substituteInPlace packages/dashboard/src/app/layout.tsx --replace-fail \
            'Geist({ subsets: ["latin"], variable: "--font-sans" })' \
            'localFont({ src: "./Geist-Regular.otf", variable: "--font-sans" })'

          cp "${prev.geist-font}/share/fonts/opentype/Geist-Regular.otf" \
            packages/dashboard/src/app/Geist-Regular.otf
        '';

        buildPhase = ''
          runHook preBuild
          pnpm --filter dashboard build
          runHook postBuild
        '';

        installPhase = ''
          runHook preInstall
          cp -r packages/dashboard/out $out
          runHook postInstall
        '';
      };
    in
    {
      agent-browser = prev.rustPlatform.buildRustPackage (finalAttrs: {
        pname = "agent-browser";
        inherit version src;

        sourceRoot = "${finalAttrs.src.name}/cli";

        cargoHash = "sha256-6uViJNJRcXbLs0MwHyxAvju5hdlSX/XjEdFTGTuvb+4=";

        postUnpack = ''
          chmod u+w source/packages/dashboard
          cp -r ${dashboard} source/packages/dashboard/out
        '';

        postPatch = ''
          substituteInPlace src/doctor/helpers.rs src/install.rs --replace-fail \
            '"which"' '"${prev.lib.getExe prev.which}"'
        '';

        nativeCheckInputs = [
          prev.writableTmpDirAsHomeHook
        ];

        __darwinAllowLocalNetworking = true;

        postInstall = ''
          cp -r ../skills $out/skills
          cp -r ../skill-data $out/skill-data
        '';

        passthru = {
          inherit dashboard;
        };

        meta = (prev.agent-browser.meta or { }) // {
          description = "Headless browser automation CLI for AI agents (pinned for pi-agent-browser-native)";
          homepage = "https://github.com/vercel-labs/agent-browser";
          mainProgram = "agent-browser";
        };
      });
    };
}
