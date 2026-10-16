#!/usr/bin/env bash
# The server runs its pinned headless browser from a fixed path in its home
# directory and downloads it there when the path is empty. That download is
# an FHS binary that does not start on NixOS, so link the patched store copy
# into the same place first. Failing to link is not fatal: the server then
# falls back to its own download and reports what is missing.

# Same precedence as the server: --base-dir, then T3CODE_HOME, then ~/.t3.
base=${T3CODE_HOME:-}
prev=
for arg in "$@"; do
  case $prev in --base-dir) base=$arg ;; esac
  case $arg in --base-dir=*) base=${arg#--base-dir=} ;; esac
  prev=$arg
done
case $base in
  "") base=$HOME/.t3 ;;
  \~) base=$HOME ;;
  \~/*) base=$HOME/${base#\~/} ;;
esac

link=$base/tools/chrome-headless-shell/linux64/@browserVersion@
if [ "$(readlink "$link" 2>/dev/null)" != @browser@ ]; then
  # A directory here is the server's own unpatched download of this version.
  { mkdir -p "${link%/*}" && rm -rf "$link" && ln -s @browser@ "$link"; } 2>/dev/null || true
fi

exec @t3@ "$@"
