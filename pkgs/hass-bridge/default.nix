{
  lib,
  stdenv,
  fetchFromGitHub,
  python3,
  makeWrapper,
  networkmanager,
}:

stdenv.mkDerivation rec {
  pname = "hass-bridge";
  version = "0.5.0";

  src = fetchFromGitHub {
    owner = "konradk";
    repo = "hass";
    rev = "v${version}";
    hash = "sha256-sQWBX4avXEfOc900AYPZyHH9xNvBA5iB8+J6zqajPE8=";
  };

  nativeBuildInputs = [ makeWrapper ];

  installPhase = ''
    runHook preInstall
    mkdir -p $out/bin $out/share/hass
    cp -r bin vendor $out/share/hass/
    chmod +x $out/share/hass/bin/hass-bridge
    makeWrapper ${python3}/bin/python3 $out/bin/hass-bridge \
      --add-flags "$out/share/hass/bin/hass-bridge" \
      --prefix PATH : ${lib.makeBinPath [ networkmanager ]}
    runHook postInstall
  '';

  meta = with lib; {
    description = "Home Assistant WebSocket bridge for the hass Quickshell plugin";
    homepage = "https://github.com/konradk/hass";
    license = licenses.mit;
    platforms = platforms.linux;
    mainProgram = "hass-bridge";
  };
}
