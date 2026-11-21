#!/usr/bin/env bash
# Tests script/update-cask.sh against fake feeds (local web server): no network, no real release needed.
# Covers: up to date, older feed, garbage feed, missing dmg, SHA mismatch, the successful bump.
set -euo pipefail
cd "$(dirname "$0")/.."
PORT=8821
T=$(mktemp -d); mkdir -p "$T/web/rel/v9.9.9" "$T/web/download"
python3 -m http.server "$PORT" --bind 127.0.0.1 --directory "$T/web" >/dev/null 2>&1 & srv=$!
disown
trap 'kill $srv 2>/dev/null || true; rm -rf "$T"' EXIT
sleep 1
fails=0
check() { if [[ "$2" == "$3" ]]; then echo "ok   $1"; else echo "FAIL $1: got [$2] want [$3]"; fails=1; fi }
feed() { printf '<?xml version="1.0"?><rss xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle"><channel><item><sparkle:shortVersionString>%s</sparkle:shortVersionString></item></channel></rss>' "$1" >"$T/web/appcast.xml"; }
site() { printf '<html><code>%s</code></html>' "$1" >"$T/web/download/index.html"; }
cask() { sed -E -e "s/^( *version )\"[^\"]*\"/\1\"$1\"/" Casks/chopastem.rb >"$T/chopastem.rb"; }
run() { CASK="$T/chopastem.rb" APPCAST_URL="http://127.0.0.1:$PORT/appcast.xml" SITE_DOWNLOAD_URL="http://127.0.0.1:$PORT/download/" \
        RELEASES_URL="http://127.0.0.1:$PORT/rel" SKIP_NOTARIZE_CHECK=1 script/update-cask.sh 2>&1; }
ver() { sed -nE 's/^ *version "([^"]+)".*/\1/p' "$T/chopastem.rb"; }

printf 'fake dmg bytes' >"$T/web/rel/v9.9.9/ChopAStem-9.9.9.dmg"
GOOD=$(shasum -a 256 "$T/web/rel/v9.9.9/ChopAStem-9.9.9.dmg" | cut -d' ' -f1)

cask 1.0.0; feed 1.0.0; site "$GOOD"; out=$(run); check "same version: no change" "$(ver)" 1.0.0
if [[ "$out" == *"up to date"* ]]; then echo "ok   says up to date"; else echo "FAIL message: $out"; fails=1; fi
cask 2.0.0; feed 1.5.0; out=$(run); check "older feed never downgrades" "$(ver)" 2.0.0
cask 1.0.0; feed "not-a-version"; if run >/dev/null; then echo "FAIL garbage feed accepted"; fails=1; else echo "ok   garbage feed refused"; fi; check "garbage feed leaves the cask alone" "$(ver)" 1.0.0
cask 1.0.0; feed 9.9.8; if run >/dev/null; then echo "FAIL missing dmg accepted"; fails=1; else echo "ok   missing dmg refused"; fi; check "missing dmg leaves the cask alone" "$(ver)" 1.0.0
cask 1.0.0; feed 9.9.9; site "$(printf '0%.0s' {1..64})"; if run >/dev/null; then echo "FAIL hash mismatch accepted"; fails=1; else echo "ok   SHA mismatch refused"; fi; check "mismatch leaves the cask alone" "$(ver)" 1.0.0
cask 1.0.0; feed 9.9.9; site ""; if run >/dev/null; then echo "FAIL missing site hash accepted"; fails=1; else echo "ok   site without a hash refused"; fi
cask 1.0.0; feed 9.9.9; site "$GOOD"; out=$(run); check "newer, verified: bumps the version" "$(ver)" 9.9.9
check "...and the hash" "$(grep -c "sha256 \"$GOOD\"" "$T/chopastem.rb")" 1
check "...and leaves the url line alone" "$(grep -c 'url "https://github.com/TheMusicDev/chopastem-releases/releases/download/v#{version}/ChopAStem-#{version}.dmg"' "$T/chopastem.rb")" 1
check "10 sorts after 9 (not as text)" "$(cask 9.9.9; feed 10.0.0; mkdir -p "$T/web/rel/v10.0.0"; cp "$T/web/rel/v9.9.9/ChopAStem-9.9.9.dmg" "$T/web/rel/v10.0.0/ChopAStem-10.0.0.dmg"; site "$GOOD"; run >/dev/null; ver)" 10.0.0
if [[ $fails -ne 0 ]]; then echo "update-cask checks FAILED"; exit 1; fi
echo "update-cask checks passed"
