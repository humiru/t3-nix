{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  callPackage,
  runtimeShell,
  sources,
}: let
  browser = callPackage ./browser.nix {inherit sources;};
in
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
      # so the wrapper can exec it from here.
      substitute ${./server-wrapper.sh} $out/bin/t3 \
        --replace-fail '#!/usr/bin/env bash' '#!${runtimeShell}' \
        --subst-var-by t3 $out/lib/t3code/t3 \
        --subst-var-by browser ${browser} \
        --subst-var-by browserVersion ${browser.version}
      chmod +x $out/bin/t3

      runHook postInstall
    '';

    # autoPatchelf sets the interpreter, then the rpath, in two patchelf runs.
    # On `t3` (a non-PIE EXEC whose program headers Node's SEA injector already
    # moved) patchelf 0.18 and 0.19.2 then stretch the page they prepended for
    # the interpreter over the next LOAD segment, and the binary segfaults
    # before main. Rpath first, interpreter second yields a sound layout. So
    # autoPatchelf patches a scratch copy, its values go onto the real binary
    # in the safe order, and the hook's own pass over it changes nothing:
    # patchelf leaves the file untouched when a value is already set.
    # Runs before autoPatchelfPostFixup: the implicit hook comes first.
    # TODO: on a patchelf bump, drop this postFixup and check whether plain
    # autoPatchelf passes the install check again.
    postFixup = ''
      scratch=$(mktemp -d)
      cp $out/lib/t3code/t3 $scratch/t3
      autoPatchelf $scratch
      patchelf --set-rpath "$(patchelf --print-rpath $scratch/t3)" $out/lib/t3code/t3
      patchelf --set-interpreter "$(patchelf --print-interpreter $scratch/t3)" $out/lib/t3code/t3
      rm -r $scratch
    '';

    # Runs in the sandbox, where no /lib64 loader exists: proves the patched
    # binary still starts and that sources.json points at the version it claims,
    # that the wrapper linked the browser, and that the binary pins the same
    # browser archive sources.json fetched.
    doInstallCheck = true;
    installCheckPhase = ''
      runHook preInstallCheck
      HOME=$TMPDIR $out/bin/t3 --version | tee /dev/stderr | grep -qF '${sources.version}'
      test -x $TMPDIR/.t3/tools/chrome-headless-shell/linux64/${browser.version}/chrome-headless-shell
      grep -qaF '${builtins.convertHash {
        hash = sources.browser.hash;
        toHashFormat = "base16";
      }}' $out/lib/t3code/t3
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
