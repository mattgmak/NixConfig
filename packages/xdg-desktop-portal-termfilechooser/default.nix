{ lib, stdenv, fetchFromGitHub, meson, ninja, pkg-config, scdoc, systemd, }:

stdenv.mkDerivation {
  pname = "xdg-desktop-portal-termfilechooser";
  version = "unstable-2024-02-18";

  src = fetchFromGitHub {
    owner = "hunkyburrito";
    repo = "xdg-desktop-portal-termfilechooser";
    rev = "a1194c7a2e029d6f07b64e35da475e28a383dcf4";
    hash = "sha256-IMoqpBH4Ny48bec9aDomjL8Y607vW4sE3FlXhaVQbLE=";
  };

  nativeBuildInputs = [ meson ninja pkg-config scdoc systemd ];

  buildInputs = [ systemd ];

  mesonFlags = [ "-Dsd-bus-provider=systemd" "-Ddefault-file-manager=yazi" ];

  # Add proper build steps
  buildPhase = ''
    meson setup build
    ninja -C build
  '';

  installPhase = ''
    ninja -C build install
  '';

  meta = with lib; {
    description =
      "XDG Desktop Portal for choosing files through a terminal file chooser";
    homepage = "https://github.com/GermainZ/xdg-desktop-portal-termfilechooser";
    license = licenses.gpl3Plus;
    platforms = platforms.linux;
    maintainers = with maintainers; [ ];
  };
}
