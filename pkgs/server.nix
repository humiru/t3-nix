{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  sources,
}:
stdenv.mkDerivation {
  pname = "t3code-server";
  inherit (sources) version;

  src = fetchurl {inherit (sources.server) url hash;};

  nativeBuildInputs = [autoPatchelfHook];
  buildInputs = [stdenv.cc.cc.lib];

  # `t3` is a Node single-executable application: the JS bundle lives in a
  # non-allocated ELF note section that strip is free to drop.
  dontStrip = true;

  installPhase = ''
    runHook preInstall

    mkdir -p $out/lib/t3code $out/bin
    cp -r . $out/lib/t3code

    # Prebuilt addons for a libc we do not run on; autoPatchelf cannot
    # satisfy them and the server never loads them on glibc.
    find $out/lib/t3code/node_modules -type d -name '*-musl' -prune -exec rm -r {} +

    # The binary locates client/ and node_modules/ next to its real path,
    # so a symlink is enough.
    ln -s $out/lib/t3code/t3 $out/bin/t3

    runHook postInstall
  '';

  # Runs in the sandbox, where no /lib64 loader exists: proves the patched
  # binary still starts and that sources.json points at the version it claims.
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    HOME=$TMPDIR $out/bin/t3 --version | tee /dev/stderr | grep -qF '${sources.version}'
    runHook postInstallCheck
  '';

  meta = {
    description = "T3 Code headless server and CLI";
    homepage = "https://t3.codes";
    changelog = "https://github.com/pingdotgg/t3code/releases/tag/v${sources.version}";
    license = lib.licenses.mit;
    sourceProvenance = [lib.sourceTypes.binaryNativeCode];
    platforms = ["x86_64-linux"];
    mainProgram = "t3";
  };
}
