{ lib, stdenv, fetchFromGitHub, }:

stdenv.mkDerivation {
  pname = "yaziPlugins-relative-motions";
  version = "unstable-2024-12-14";

  src = fetchFromGitHub {
    owner = "dedukun";
    repo = "relative-motions.yazi";
    rev = "df97039a04595a40a11024f321a865b3e9af5092";
    hash = "sha256-csX8T2a5f7k6g2mlR+08rm0qBeWdI4ABuja+klIvwqw=";
  };

  installPhase = ''
    mkdir -p $out/share/yazi/plugins/relative-motions
    cp -r $src/* $out/share/yazi/plugins/relative-motions/

    echo ""
    echo "================================================================"
    echo "                  YAZI PLUGIN MODIFICATION LOG                    "
    echo "================================================================"

    echo "Checking original content..."
    grep -A 1 'if cmd == "j"\|if cmd == "k"\|direction == "j"\|direction == "k"\|cmd = "j"\|cmd = "k"' $out/share/yazi/plugins/relative-motions/init.lua

    echo -e "\nPerforming key swaps..."
    # First, replace all j with TEMP_J
    sed -i 's/"j"/"TEMP_J"/g' $out/share/yazi/plugins/relative-motions/init.lua
    # Then replace all k with j
    sed -i 's/"k"/"j"/g' $out/share/yazi/plugins/relative-motions/init.lua
    # Finally replace TEMP_J with k
    sed -i 's/"TEMP_J"/"k"/g' $out/share/yazi/plugins/relative-motions/init.lua

    echo -e "\nVerifying changes..."
    grep -A 1 'if cmd == "j"\|if cmd == "k"\|direction == "j"\|direction == "k"\|cmd = "j"\|cmd = "k"' $out/share/yazi/plugins/relative-motions/init.lua

    echo "================================================================"
    echo ""
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
