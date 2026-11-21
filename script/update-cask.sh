#!/usr/bin/env bash
# Bump Casks/chopastem.rb when chopastem.com's update feed announces a newer version. Run by the scheduled GitHub
# Action (.github/workflows/update-cask.yml); also fine to run by hand. Needs: curl, xmllint, shasum, sed.
#
# It only edits the cask, and only after every check passes:
#   1. the feed's version is newer than the cask's (never downgrades, never acts on garbage)
#   2. the dmg downloads from the GitHub Release
#   3. the dmg's SHA-256 equals the one printed on chopastem.com/download/ (two independent sources agree)
#   4. on a Mac: the app inside the dmg is signed + notarized by Apple (never publish an unverified build)
# Any failure exits non-zero and leaves the cask untouched (the Action then shows red and GitHub emails you).
#
# Test hooks (env): CASK, APPCAST_URL, SITE_DOWNLOAD_URL, RELEASES_URL, SKIP_NOTARIZE_CHECK=1 (see script/check-update-cask.sh)
set -euo pipefail
cd "$(dirname "$0")/.."
CASK=${CASK:-Casks/chopastem.rb}
APPCAST_URL=${APPCAST_URL:-https://chopastem.com/appcast.xml}
SITE_DOWNLOAD_URL=${SITE_DOWNLOAD_URL:-https://chopastem.com/download/}
RELEASES_URL=${RELEASES_URL:-https://github.com/TheMusicDev/chopastem-releases/releases/download}

die() { echo "update-cask: $*" >&2; exit 1; }
TMP=$(mktemp -d); trap 'hdiutil detach -quiet "$TMP/mnt" 2>/dev/null || true; rm -rf "$TMP"' EXIT

current=$(sed -nE 's/^ *version "([^"]+)".*/\1/p' "$CASK" | head -1)
[[ -n "$current" ]] || die "can't read the current version from $CASK"

new=$(curl -fsS --max-time 30 "$APPCAST_URL" | xmllint --xpath 'string(//*[local-name()="shortVersionString"])' - 2>/dev/null) || die "can't read $APPCAST_URL"
[[ "$new" =~ ^[0-9]+(\.[0-9]+){1,3}$ ]] || die "the feed's version doesn't look like a version: '$new'"

if [[ "$new" == "$current" || "$(printf '%s\n%s\n' "$current" "$new" | sort -V | tail -1)" != "$new" ]]; then
  echo "up to date: cask $current, feed $new"
  exit 0
fi
echo "feed announces $new, cask has $current: verifying before updating"

dmg="$TMP/ChopAStem-$new.dmg"
curl -fsSL --max-time 300 -o "$dmg" "$RELEASES_URL/v$new/ChopAStem-$new.dmg" || die "can't download the $new dmg from the GitHub Release"
sha=$(shasum -a 256 "$dmg" | cut -d' ' -f1)

site_sha=$(curl -fsS --max-time 30 "$SITE_DOWNLOAD_URL" | grep -oE '\b[0-9a-f]{64}\b' | head -1 || true)
[[ -n "$site_sha" ]] || die "no SHA-256 found on $SITE_DOWNLOAD_URL (has the site been deployed for $new?)"
[[ "$sha" == "$site_sha" ]] || die "SHA-256 mismatch: the dmg is $sha but the site says $site_sha. Not updating."

if [[ "$(uname)" == Darwin && -z "${SKIP_NOTARIZE_CHECK:-}" ]]; then
  mkdir "$TMP/mnt"
  hdiutil attach -nobrowse -quiet -readonly -mountpoint "$TMP/mnt" "$dmg" || die "can't open the dmg"
  spctl -a -t exec -vv "$TMP/mnt/ChopAStem.app" 2>&1 | grep -q "source=Notarized Developer ID" || die "the app in the $new dmg is not notarized by Apple. Not updating."
  xcrun stapler validate "$TMP/mnt/ChopAStem.app" >/dev/null 2>&1 || die "the notarization ticket is not stapled to the app. Not updating."
fi

sed -i.bak -E -e "s/^( *version )\"[^\"]*\"/\1\"$new\"/" -e "s/^( *sha256 )\"[^\"]*\"/\1\"$sha\"/" "$CASK" && rm -f "$CASK.bak"
if ! grep -q "version \"$new\"" "$CASK" || ! grep -q "sha256 \"$sha\"" "$CASK"; then die "the cask didn't take the new values"; fi
echo "updated $CASK: $current -> $new ($sha)"
