# Homebrew tap for ChopAStem

[ChopAStem](https://chopastem.com/) splits any song into vocals, drums, bass and other stems, entirely on your Mac. Free, no account. Apple Silicon (M1 and every later chip), macOS 14 or newer.

```
brew install --cask themusicdev/tap/chopastem
```

- The app updates itself (Sparkle), so `brew upgrade` is not needed. `brew upgrade --cask --greedy chopastem` also works.
- Homebrew 7 asks you to trust third-party taps. Installing with the full name above trusts this cask automatically. If a later command says "untrusted tap", run `brew trust themusicdev/tap`.
- Remove: `brew uninstall --cask --zap chopastem` (also deletes its settings and caches).

The cask is updated by hand after each release from [chopastem-releases](https://github.com/TheMusicDev/chopastem-releases). Source and issues: [ChopAStem-Desktop](https://github.com/TheMusicDev/ChopAStem-Desktop).
