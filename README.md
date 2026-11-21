# Homebrew tap for ChopAStem

[ChopAStem](https://chopastem.com/) splits any song into vocals, drums, bass and other stems, entirely on your Mac. Free, no account. Apple Silicon (M1 and every later chip), macOS 14 or newer.

```
brew install --cask themusicdev/tap/chopastem
```

- The app updates itself (Sparkle), so `brew upgrade` is not needed. `brew upgrade --cask --greedy chopastem` also works.
- Homebrew 7 asks you to trust third-party taps. Installing with the full name above trusts this cask automatically. If a later command says "untrusted tap", run `brew trust themusicdev/tap`.
- Remove: `brew uninstall --cask --zap chopastem` (also deletes its settings and caches).

Source and issues: [ChopAStem-Desktop](https://github.com/TheMusicDev/ChopAStem-Desktop).

---

## For maintainers

### How the name works
Homebrew finds a tap `user/name` in the GitHub repo `user/homebrew-name`. This repo is `TheMusicDev/homebrew-tap`, so the tap is `themusicdev/tap`, and the cask file `Casks/chopastem.rb` becomes `themusicdev/tap/chopastem`.

### How it stays up to date
Homebrew is never told about a release. The cask file holds a fixed `version`, `sha256` and download URL, so something has to edit it. That is `.github/workflows/update-cask.yml`, **every 6 hours** (and on demand):

```
ChopAStem-Desktop  script/release.sh
   builds, notarizes, publishes ChopAStem-X.Y.Z.dmg to the chopastem-releases GitHub Release
        |
chopastem-site     you deploy the site (script/deploy.sh)
   chopastem.com/appcast.xml now says X.Y.Z, and /download/ prints the dmg's SHA-256
        |
homebrew-tap       the schedule (within 6 hours) runs script/update-cask.sh
   feed is newer than the cask  ->  download the dmg  ->  its SHA-256 equals the one on /download/
   ->  the app inside is notarized by Apple  ->  edit version + sha256, commit, push to main
```

So **deploy the site first**: until `appcast.xml` announces the version, the tap does nothing. To publish to Homebrew right away instead of waiting up to 6 hours:

```
gh workflow run update-cask.yml --repo TheMusicDev/homebrew-tap
```

`script/update-cask.sh` changes nothing unless every check passes: the feed's version is newer (never a downgrade), the dmg downloads, the dmg's hash matches the website's, and (on a Mac) the app is signed and notarized. On any failure the run goes red, the cask stays as it was, and GitHub emails the person who last edited the workflow. Fix the cause and re-run.

Two details worth knowing:
- GitHub pauses scheduled workflows after 60 days without activity in a public repo. The workflow leaves an empty "keepalive" commit after 45 quiet days so that never happens between releases.
- The cask's `livecheck` block points at the same feed, so `brew livecheck --cask themusicdev/tap/chopastem` shows what Homebrew thinks the newest version is.

### Testing
- `script/check-update-cask.sh`: the update script against fake feeds (no network; also run by the workflow every time).
- Real install into a throwaway folder: `brew tap themusicdev/tap .` then `brew install --cask --appdir=/tmp/apps themusicdev/tap/chopastem`; clean up with `brew uninstall --cask themusicdev/tap/chopastem && brew untap themusicdev/tap`.
- `brew style --cask themusicdev/tap/chopastem` and `brew audit --cask --online themusicdev/tap/chopastem` (the audit needs the tap trusted: `brew trust themusicdev/tap`).
