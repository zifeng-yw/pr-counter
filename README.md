<p align="center">
  <img src="docs/icon.png" width="128" alt="PR Counter icon">
</p>

<h1 align="center">PR Counter</h1>

<p align="center">A macOS menu bar app that shows how many GitHub pull requests you've opened.</p>

## Requirements

- macOS 15 or later
- Xcode, to build from source
- [GitHub CLI](https://cli.github.com) signed in with `gh auth login`

## Install

Download `PR-Counter-<version>.dmg` from the [latest release](https://github.com/zifeng-yw/pr-counter/releases/latest), open it, and drag PR Counter into Applications.

The app is not notarized, so macOS blocks the first launch. Clear the quarantine flag before opening it:

```sh
xattr -dr com.apple.quarantine "/Applications/PR Counter.app"
```

## Build from source

```sh
./build-app.sh
cp -R "build.noindex/PR Counter.app" /Applications/
open "/Applications/PR Counter.app"
```

`./make-dmg.sh` builds the app and packages it into `build.noindex/PR-Counter-<version>.dmg`.
