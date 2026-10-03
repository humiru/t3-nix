# t3-nix

Nix packages for [T3 Code](https://t3.codes), repackaged from the binaries
upstream attaches to each stable release. A scheduled workflow follows new
releases hourly, so `nix flake update` on the consumer side is the whole
upgrade.

| Package          | Binary           | Upstream artifact               |
| ---------------- | ---------------- | ------------------------------- |
| `t3code-server`  | `t3`             | `t3-<version>-linux-x64.tar.gz` |
| `t3code-desktop` | `t3code-desktop` | `T3-Code-<version>-x86_64.AppImage` |

Only `x86_64-linux`.

## Use

```nix
{
  inputs.t3-nix = {
    url = "github:humiru/t3-nix";
    inputs.nixpkgs.follows = "nixpkgs";
  };
}
```

```nix
{
  nixpkgs.overlays = [inputs.t3-nix.overlays.default];
  environment.systemPackages = [pkgs.t3code-server pkgs.t3code-desktop];
}
```

Or try it directly:

```sh
nix run github:humiru/t3-nix#t3code-server -- serve
nix run github:humiru/t3-nix#t3code-desktop
```

The server finds provider CLIs (`claude`, `codex`) and `git` on `PATH`; the
package does not bundle them.

## Updates

`.github/workflows/update.yml` runs hourly: it points `sources.json` at the
latest stable release, runs `nix flake check`, and pushes the bump only if the
check passes. To do the same by hand:

```sh
scripts/update.sh          # latest stable
scripts/update.sh 0.0.45   # exact version
nix flake check -L
```

## License

The packaging in this repository is MIT. T3 Code itself is MIT-licensed by
its authors; the binaries are theirs, fetched unmodified from upstream
releases.
