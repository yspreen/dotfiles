{ lib, stdenvNoCC, pkgs, ... }:

stdenvNoCC.mkDerivation {
  pname = "Figtree";
  version = "1";

  src = ./.;  # Use current directory as source
  
  dontUnpack = true;
  dontConfigure = true;

  buildInputs = [
    pkgs.curl
    pkgs.woff2
    pkgs.bash
    pkgs.cacert
    (pkgs.python3.withPackages (ps: with ps; [ fonttools ]))
  ];

  SSL_CERT_FILE = "${pkgs.cacert}/etc/ssl/certs/ca-bundle.crt";

  buildPhase = ''
    cp ${./google.sh} ./google.sh
    chmod +x ./google.sh
    cp ${./rename.py} ./rename.py
  '';

  installPhase = ''
    mkdir -p $out/share/fonts/truetype/
    ./google.sh Figtree Figtree variable $out/share/fonts/truetype/
  '';

  meta = {
    description = "Figtree Google Font";
    homepage = "https://fonts.google.com/specimen/Figtree";
    license = lib.licenses.ofl;
  };
}
