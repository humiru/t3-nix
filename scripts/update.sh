#!/usr/bin/env bash
# Point sources.json at an upstream release. Hashes come from the checksum
# files upstream publishes with each release and, for the headless browser
# the server pins, from the server source at the release tag. Nothing large
# is downloaded here; `nix flake check` afterwards proves the hashes and the
# build. Rewrites sources.json even when the version is unchanged, so a run
# also fills in fields added to the format.
#
# Usage: scripts/update.sh [version]   (default: latest stable release)
set -euo pipefail

repo=https://github.com/pingdotgg/t3code
cd "$(dirname "$0")/.."

version=${1:-}
if [ -z "$version" ]; then
  # /releases/latest redirects to the newest non-prerelease tag. Unlike the
  # REST API this is not rate-limited for anonymous hourly polling.
  tag_url=$(curl -fsSL -o /dev/null -w '%{url_effective}' "$repo/releases/latest")
  version=${tag_url##*/v}
fi
if ! [[ $version =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
  echo "refusing non-stable version: '$version'" >&2
  exit 1
fi

current=$(jq -r .version sources.json)

base=$repo/releases/download/v$version
server=t3-$version-linux-x64.tar.gz
desktop=T3-Code-$version-x86_64.AppImage

server_hex=$(curl -fsSL "$base/SHA256SUMS" | awk -v f="$server" '$2 == f { print $1 }')
manifest=$(curl -fsSL "$base/latest-linux.yml")
# The top-level path/sha512 pair of the electron-updater manifest describes
# the AppImage; check the name so a layout change fails here, not at build.
manifest_path=$(awk '$1 == "path:" { print $2 }' <<<"$manifest")
desktop_b64=$(awk '$1 == "sha512:" && !/^ / { print $2 }' <<<"$manifest")

if [ -z "$server_hex" ] || [ -z "$desktop_b64" ] || [ "$manifest_path" != "$desktop" ]; then
  echo "release v$version does not have the expected assets" >&2
  exit 1
fi

# The server downloads a pinned Chrome for Testing headless shell on first
# use; the pin lives in this file as a version and per-platform SHA-256.
browser_source=$(curl -fsSL "https://raw.githubusercontent.com/pingdotgg/t3code/v$version/apps/server/src/preview/PreviewBrowser.ts")
browser_version=$(sed -nE 's/^const VERSION = "([0-9.]+)";$/\1/p' <<<"$browser_source")
browser_hex=$(awk '/^  linux64: \{/ { found = 1 } found && /sha256:/ { gsub(/[",]/, "", $2); print $2; exit }' <<<"$browser_source")

if [ -z "$browser_version" ] || ! [[ $browser_hex =~ ^[0-9a-f]{64}$ ]]; then
  echo "release v$version: could not read the browser pin from PreviewBrowser.ts" >&2
  exit 1
fi

to_sri() {
  nix --extra-experimental-features nix-command hash convert --hash-algo sha256 --to sri "$1"
}
server_hash=$(to_sri "$server_hex")
browser_hash=$(to_sri "$browser_hex")
browser_url=https://storage.googleapis.com/chrome-for-testing-public/$browser_version/linux64/chrome-headless-shell-linux64.zip

jq -n \
  --arg version "$version" \
  --arg server_url "$base/$server" --arg server_hash "$server_hash" \
  --arg desktop_url "$base/$desktop" --arg desktop_hash "sha512-$desktop_b64" \
  --arg browser_version "$browser_version" \
  --arg browser_url "$browser_url" --arg browser_hash "$browser_hash" \
  '{
    version: $version,
    server: { url: $server_url, hash: $server_hash },
    desktop: { url: $desktop_url, hash: $desktop_hash },
    browser: { version: $browser_version, url: $browser_url, hash: $browser_hash }
  }' >sources.json

if [ "$version" = "$current" ]; then
  echo "at $version"
else
  echo "updated $current -> $version"
fi
