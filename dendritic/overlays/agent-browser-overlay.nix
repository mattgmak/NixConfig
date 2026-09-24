# agent-browser 0.38.1 — supported by pi-agent-browser-native.
# Uses official release binaries; source is fetched only for bundled skills.
{ ... }:
{
  flake.agentBrowserOverlay =
    final: prev:
    let
      version = "0.38.1";

      # Fetch source only for the skill files shipped beside the binary.
      src = prev.fetchFromGitHub {
        owner = "vercel-labs";
        repo = "agent-browser";
        tag = "v${version}";
        hash = "sha256-C+XplCHOdFDQGPUnrCDuq7U4LkAX0QB3fC4uVA8o11w=";
      };

      platformName =
        if prev.stdenv.hostPlatform.isDarwin then
          if prev.stdenv.hostPlatform.isAarch64 then "darwin-arm64"
          else if prev.stdenv.hostPlatform.isx86_64 then "darwin-x64"
          else throw "agent-browser: unsupported Darwin architecture"
        else if prev.stdenv.hostPlatform.isLinux then
          if prev.stdenv.hostPlatform.isAarch64 then
            if prev.stdenv.hostPlatform.isMusl then "linux-musl-arm64" else "linux-arm64"
          else if prev.stdenv.hostPlatform.isx86_64 then
            if prev.stdenv.hostPlatform.isMusl then "linux-musl-x64" else "linux-x64"
          else throw "agent-browser: unsupported Linux architecture"
        else throw "agent-browser: unsupported platform";

      releaseHashes = {
        "darwin-arm64" = "sha256-LmEoclkFPqlk0553ACxqNK8OWJ5VzP8l5lnvrn6JLg0=";
        "darwin-x64" = "sha256-kYf4hffaCm2ID/bS596ljhe+pJCh/shbu2o2BnJy6o4=";
        "linux-arm64" = "sha256-k3sxXuB2Hopi95UN3P75s9PY6NXrnJ0r+eI+VyVmRRE=";
        "linux-x64" = "sha256-UQAUmhkDIRyIneTlRb822QgDdAzqT5mqImUWSfkgXqE=";
        "linux-musl-arm64" = "sha256-YNwfSbNlaJiojjypg0FeH07NEDQzySTx/07BGDfM2gc=";
        "linux-musl-x64" = "sha256-5LRVXEUNaQNWfxiuVywmpvhtytMcQB+bVtW8ADNK/JE=";
      };

      releaseBinary = prev.fetchurl {
        url = "https://github.com/vercel-labs/agent-browser/releases/download/v${version}/agent-browser-${platformName}";
        hash = releaseHashes.${platformName};
      };
    in
    {
      agent-browser = prev.stdenv.mkDerivation {
        pname = "agent-browser";
        inherit version;

        dontUnpack = true;
        nativeBuildInputs = [ prev.makeWrapper ];

        installPhase = ''
          runHook preInstall
          mkdir -p "$out/bin"
          install -m 755 "${releaseBinary}" "$out/bin/agent-browser"
          cp -r "${src}/skills" "$out/skills"
          cp -r "${src}/skill-data" "$out/skill-data"
          wrapProgram "$out/bin/agent-browser" --prefix PATH : ${prev.lib.makeBinPath [ prev.which ]}
          runHook postInstall
        '';

        meta = (prev.agent-browser.meta or { }) // {
          description = "Headless browser automation CLI for AI agents";
          homepage = "https://github.com/vercel-labs/agent-browser";
          mainProgram = "agent-browser";
        };
      };
    };
}
