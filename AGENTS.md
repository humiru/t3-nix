# t3-nix

Nix flake that repackages upstream [T3 Code](https://github.com/pingdotgg/t3code)
release binaries: the headless server (`t3`) and the desktop app. It exists so
that consumers get new T3 Code versions through a plain `nix flake update`.
The repository is public and mostly unattended: a bot bumps versions, a human
or agent only touches it when packaging breaks.

## Layout

- `sources.json` — the single source of truth for what is packaged: version,
  URLs, hashes. Written only by `scripts/update.sh`; never edit it by hand.
- `pkgs/server.nix` — the server tarball, patched with autoPatchelf.
- `pkgs/desktop.nix` — the AppImage, wrapped with `appimageTools`.
- `flake.nix` — packages, `overlays.default`, and `checks` (= both packages).
- `scripts/update.sh` — points `sources.json` at a release.
- `.github/workflows/update.yml` — hourly bump, gated on `nix flake check`.
- `.github/workflows/ci.yml` — check on push and PR; weekly nixpkgs refresh.

## Invariants

- **`main` always builds.** The update workflow commits a bump only after
  `nix flake check` passes. Keep that gate; do not make the workflow push
  first and check later.
- **Stable releases only.** `scripts/update.sh` rejects anything that is not
  `X.Y.Z`. Upstream nightlies ship three times a day and are not wanted here.
- **Server and desktop share one version.** T3 Code warns on client/server
  version mismatch, so both packages read the same `sources.json` version.
- **Hashes come from upstream's checksum files** (`SHA256SUMS` for the server,
  `latest-linux.yml` for the AppImage), not from downloading artifacts in the
  script. The build is what verifies them.
- **The server install check is the real test.** It runs `t3 --version` inside
  the build sandbox, where no `/lib64` loader and no nix-ld exist. A binary
  that only works on the developer's machine fails there. Never disable it.
- **Binaries only, no source build.** Building from source means tracking
  upstream's pnpm lockfile hash on every release, which cannot be automated
  from checksum files.

## Things that are not obvious

- `t3` is a Node single-executable application; the JS bundle sits in an ELF
  note section. `dontStrip` protects it. If a release stops starting after
  patching, look at how the payload is embedded before anything else.
- The tarball ships musl variants of native addons. They are deleted because
  autoPatchelf cannot satisfy them and glibc systems never load them.
- Neither package self-updates: a foreground `t3 serve` does not, and
  electron-updater is inert without `$APPIMAGE`. `t3 update` and
  `t3 service install` are upstream's own installer path and are not expected
  to work from the Nix store.
- Provider CLIs and `git` are deliberately not wrapped into `PATH`; the
  consumer's service definition decides which agents the server sees.
- Pushes made with `GITHUB_TOKEN` do not trigger other workflows. That is why
  the update workflow runs the check itself instead of relying on `ci.yml`.

## Working here

- Build and check everything: `nix flake check -L`.
- Format: `nix fmt` (alejandra). Shell: `shellcheck scripts/*.sh`.
- New files are invisible to the flake until `git add`.
- Test a packaging change against a specific release with
  `scripts/update.sh <version>`, then restore `sources.json` with git.
- Commit messages: `t3code: <version>` for bumps (the bot's format), otherwise
  `<area>: <what changed>`.
