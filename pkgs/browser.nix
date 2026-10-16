{
  lib,
  stdenv,
  fetchurl,
  unzip,
  autoPatchelfHook,
  alsa-lib,
  at-spi2-core,
  dbus,
  expat,
  glib,
  libgbm,
  libx11,
  libxcb,
  libxcomposite,
  libxdamage,
  libxext,
  libxfixes,
  libxkbcommon,
  libxrandr,
  nspr,
  nss,
  systemdLibs,
  sources,
}:
# The Chrome for Testing headless shell that the server pins for HTML previews
# and browser tabs. Upstream downloads it into the user's T3 home at runtime;
# that copy needs an FHS loader, so the server package links this one in place.
stdenv.mkDerivation {
  pname = "t3code-chrome-headless-shell";
  inherit (sources.browser) version;

  src = fetchurl {inherit (sources.browser) url hash;};

  nativeBuildInputs = [unzip autoPatchelfHook];
  buildInputs = [
    alsa-lib
    at-spi2-core
    dbus
    expat
    glib
    libgbm
    libx11
    libxcb
    libxcomposite
    libxdamage
    libxext
    libxfixes
    libxkbcommon
    libxrandr
    nspr
    nss
    systemdLibs
    stdenv.cc.cc.lib
  ];

  dontBuild = true;

  installPhase = ''
    runHook preInstall
    cp -r . $out
    runHook postInstall
  '';

  # Renders a page in the sandbox: proves every library resolves, including
  # the ones Chrome only loads once it draws. The build sandbox has no user
  # namespaces for Chrome's own sandbox, which the server does use.
  doInstallCheck = true;
  installCheckPhase = ''
    runHook preInstallCheck
    HOME=$TMPDIR $out/chrome-headless-shell --no-sandbox --disable-gpu \
      --dump-dom 'data:text/html,<p id=ok>rendered</p>' | grep -qF '<p id="ok">rendered</p>'
    runHook postInstallCheck
  '';

  meta = {
    description = "Chrome for Testing headless shell pinned by T3 Code";
    homepage = "https://googlechromelabs.github.io/chrome-for-testing/";
    license = lib.licenses.bsd3;
    sourceProvenance = [lib.sourceTypes.binaryNativeCode];
    platforms = ["x86_64-linux"];
  };
}
