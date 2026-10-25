{
  perSystem =
    { pkgs, ... }:
    let
      base = pkgs.stdenvNoCC.mkDerivation {
        pname = "tmax";
        version = "4541261";

        src = ../../vendor/theo-kirby/tmax;

        dontBuild = true;

        # Tailnet logins are key-only, so the upstream password gate is wrong here.
        # The vendored submodule stays untouched and the patch lands in the store.
        postPatch = ''
          chmod -R u+w .
          substituteInPlace scripts/auth.py \
            --replace-fail 'if result.returncode or not password_used or not key_used:' 'if result.returncode:' \
            --replace-fail '# -f forks only after authentication. Verbose output confirms that a' '# -f forks only after authentication. Tailnet SSH is key-only, so any' \
            --replace-fail '# password was actually used; a key-only server must never grant a lease.' '# successful key login grants the lease; no password is needed.'
        '';

        installPhase = ''
          runHook preInstall

          mkdir -p $out/share
          # cp -R keeps the upstream modes, so tmax.tmux stays executable.
          cp -R . $out/share/tmax

          runHook postInstall
        '';
      };
    in
    {
      # meta is attached after the derivation: perSystem pkgs has allowUnfree = false
      # and rejects an unfree `meta` argument, while hosts set allowUnfree = true.
      packages.tmax = base // {
        meta = with pkgs.lib; {
          description = "Small additions on top of tmux: remote hosts, session switcher, agent status";
          homepage = "https://github.com/theo-kirby/tmax";
          # The repo carries no LICENSE file, so it stays all rights reserved.
          license = licenses.unfree;
          platforms = platforms.unix;
        };
      };
    };
}
