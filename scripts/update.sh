#!/usr/bin/env bash
# Point sources.json at an upstream release. Hashes come from the checksum
# files upstream publishes with each release, so nothing large is downloaded
# here; `nix flake check` afterwards is what proves the hashes and the build.
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
if [ "$version" = "$current" ]; then
  echo "already at $version"
  exit 0
fi

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

server_hash=$(nix --extra-experimental-features nix-command hash convert --hash-algo sha256 --to sri "$server_hex")

jq -n \
  --arg version "$version" \
  --arg server_url "$base/$server" --arg server_hash "$server_hash" \
  --arg desktop_url "$base/$desktop" --arg desktop_hash "sha512-$desktop_b64" \
  '{
    version: $version,
    server: { url: $server_url, hash: $server_hash },
    desktop: { url: $desktop_url, hash: $desktop_hash }
  }' >sources.json

echo "updated $current -> $version"
