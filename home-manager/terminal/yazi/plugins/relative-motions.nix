{ lib, stdenv, fetchFromGitHub, }:

stdenv.mkDerivation {
  pname = "yaziPlugins-relative-motions";
  version = "unstable-2025-06-15";

  src = fetchFromGitHub {
    owner = "dedukun";
    repo = "relative-motions.yazi";
    rev = "2e3b6172e6226e0db96aea12d09dea2d2e443fea";
    hash = "sha256-v0e06ieBKNmt9DATdL7R4AyVFa9DlNBwpfME3LHozLA=";
  };

  installPhase = ''
    mkdir -p $out/share/yazi/plugins/relative-motions
    cp -r $src/* $out/share/yazi/plugins/relative-motions/

    # Create a log file
    LOG_FILE="$out/share/yazi/plugins/relative-motions/modification.log"
    touch $LOG_FILE

    {
      echo ""
      echo "================================================================"
      echo "                  YAZI PLUGIN MODIFICATION LOG                    "
      echo "================================================================"

      echo "Checking original content..."
      grep -A 1 'if cmd == "j"\|if cmd == "k"\|direction == "j"\|direction == "k"\|cmd = "j"\|cmd = "k"' $out/share/yazi/plugins/relative-motions/main.lua

      echo -e "\nPerforming key swaps..."
      # First, replace all j with TEMP_J
      sed -i 's/"j"/"TEMP_J"/g' $out/share/yazi/plugins/relative-motions/main.lua
      # Then replace all k with j
      sed -i 's/"k"/"j"/g' $out/share/yazi/plugins/relative-motions/main.lua
      # Finally replace TEMP_J with k
      sed -i 's/"TEMP_J"/"k"/g' $out/share/yazi/plugins/relative-motions/main.lua

      echo -e "\nVerifying changes..."
      grep -A 1 'if cmd == "j"\|if cmd == "k"\|direction == "j"\|direction == "k"\|cmd = "j"\|cmd = "k"' $out/share/yazi/plugins/relative-motions/main.lua

      echo "================================================================"
      echo "Done!"
    } 2>&1 | tee "$LOG_FILE"
  '';

  meta = with lib; {
    description =
      "This plugin adds the some basic vim motions like 3k, 12j, 10gg, etc.";
    homepage = "https://github.com/dedukun/relative-motions.yazi.git";
    license = licenses.mit;
    maintainers = [ ];
    platforms = platforms.all;
  };
}
