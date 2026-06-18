# Abyss Jellyfin theme overlay — https://github.com/AumGupta/abyss-jellyfin
# Patches jellyfin-web: CDN CSS in index.html, spotlight assets, home-html chunk.
{ ... }:
{
  flake.abyssJellyfinOverlay =
    final: prev:
    let
      # Current rev: 968961e, verifies against jellyfin-web ~10.11.x (webpack chunk 8372, module 5939)
      abyssSrc = prev.fetchFromGitHub {
        owner = "AumGupta";
        repo = "abyss-jellyfin";
        rev = "968961e2e75d516859ef233f2cc6f2c7785edfd8";
        hash = "sha256-e+pPIVsuZnwvYbUEjL0RJAmfHGtwU9Ik/S66jTIfL54=";
      };
    in
    {
      inherit abyssSrc;

      jellyfin-web = prev.jellyfin-web.overrideAttrs (old: {
        postInstall = (old.postInstall or "") + ''

          # ---- Abyss Jellyfin theme integration ----

          echo "abyss-jellyfin: injecting CSS into index.html"
          # Inject Abyss CDN stylesheet before </head> (after Jellyfin's own CSS so overrides work)
          sed -i 's|</head>|<link rel="stylesheet" href="https://cdn.jsdelivr.net/gh/AumGupta/abyss-jellyfin@main/abyss.css"></head>|' \
            "$out/share/jellyfin-web/index.html"

          echo "abyss-jellyfin: deploying spotlight files"
          mkdir -p "$out/share/jellyfin-web/ui"
          cp ${abyssSrc}/scripts/spotlight/spotlight.html "$out/share/jellyfin-web/ui/"
          cp ${abyssSrc}/scripts/spotlight/spotlight.css  "$out/share/jellyfin-web/ui/"

          echo "abyss-jellyfin: patching home-html chunk"
          CHUNK_FILE=$(find "$out/share/jellyfin-web" -maxdepth 1 -name "home-html.*.chunk.js" | head -1)
          if [ -n "$CHUNK_FILE" ]; then
            cp -f "$CHUNK_FILE" "''${CHUNK_FILE}.bak"
            cp -f ${abyssSrc}/scripts/spotlight/home-html.chunk.js "$CHUNK_FILE"
            echo "abyss-jellyfin: patched $(basename "$CHUNK_FILE")"
          else
            echo "abyss-jellyfin: WARNING — home-html chunk not found, spotlight disabled"
          fi
        '';
      });
    };
}
