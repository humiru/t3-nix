{
  lib,
  appimageTools,
  fetchurl,
  sources,
}: let
  pname = "t3code-desktop";
  inherit (sources) version;
  src = fetchurl {inherit (sources.desktop) url hash;};
  contents = appimageTools.extract {inherit pname version src;};
in
  appimageTools.wrapType2 {
    inherit pname version src;

    # Self-update needs no switch: electron-updater only acts when $APPIMAGE
    # points at the running image, and the wrapper runs an extracted copy.
    extraInstallCommands = ''
      install -Dm444 ${contents}/t3code.desktop $out/share/applications/t3code.desktop
      substituteInPlace $out/share/applications/t3code.desktop \
        --replace-fail 'Exec=AppRun --no-sandbox' 'Exec=${pname}'
      cp -r ${contents}/usr/share/icons $out/share/icons
    '';

    meta = {
      description = "T3 Code desktop app";
      homepage = "https://t3.codes";
      changelog = "https://github.com/pingdotgg/t3code/releases/tag/v${version}";
      license = lib.licenses.mit;
      sourceProvenance = [lib.sourceTypes.binaryNativeCode];
      platforms = ["x86_64-linux"];
      mainProgram = pname;
    };
  }
