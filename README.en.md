🌏 [简体中文](./README.md) | English

# DeepSeek Harness Desktop Lite (macOS)

[![License](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/platform-macOS%2012%2B-lightgrey.svg)](#prerequisites)
[![Unofficial](https://img.shields.io/badge/status-unofficial-orange.svg)](#disclaimer)

A **lightweight** macOS desktop wrapper (~250 KB, no Electron) around the [DeepSeek Harness](https://github.com/deepseek-ai/deepseek-harness) Web GUI: native Swift + WKWebView.

**Launch to start, close to stop** — double-click the app and it boots `dsh web` automatically and shows the UI; close the window and it stops the service it started. No terminal needed.

The app chrome (menus, error page) follows your system language and switches between English / 中文 automatically.

## Disclaimer

> ⚠️ **This is an unofficial community project**, not affiliated with, endorsed by, or sponsored by DeepSeek (深度求索).
> "DeepSeek" and the whale logo are trademarks of DeepSeek; they are used here only for compatibility references
> and imply no official relationship. The app icon is a black recolor of the DeepSeek icon from LobeHub lobe-icons (MIT);
> replace it with your own artwork if you redistribute.

## Features

- Double-click to start: probes `127.0.0.1:3080`; boots `dsh web` in the background if not running (logs: `~/.dsh/logs/desktop-web.log`)
- Close window = quit app = stop the server it started (a terminal-started server is never touched)
- Recovers ownership of its own server after a crash (pid file)
- Full standard menus: Edit (undo/cut/copy/paste/select-all), View (⌘R reload), Window (⌘M/⌘W)
- `target="_blank"` links open in your default browser
- Black whale app icon (full-resolution .icns)
- English / 中文 chrome, auto-switching with the system language

## Prerequisites

- **macOS 12+** (Apple Silicon or Intel)
- **Xcode Command Line Tools** (provides `swiftc`):
  ```sh
  xcode-select --install
  ```
- **Node.js 22.19+ or 24+** (required by DeepSeek Harness)
- **The `dsh` CLI**, either:

  **Option 1: install from npm (recommended)**
  ```sh
  npm install -g @deepseek-ai/dsh
  # verify:
  dsh web --help
  ```
  If your npm global prefix is non-standard, check it with `npm config get prefix`
  and point the app's `dsBin` at the real path (see Configuration below).

  **Option 2: run from source**
  ```sh
  git clone https://github.com/deepseek-ai/deepseek-harness.git ~/deepseek-harness
  cd ~/deepseek-harness
  pnpm install
  pnpm run build
  pnpm dsh web     # verify it boots (Ctrl+C to exit)
  ```
  Then create a global wrapper script (`~/.npm-global/bin/dsh`, on PATH):
  ```sh
  mkdir -p ~/.npm-global/bin
  cat > ~/.npm-global/bin/dsh <<'EOF'
  #!/bin/bash
  cd "$HOME/deepseek-harness" || exit 1
  exec node --import tsx/esm apps/cli/src/bin.ts "$@"
  EOF
  chmod +x ~/.npm-global/bin/dsh
  ```
  (`pnpm` is available through Corepack: `corepack enable pnpm`.)

## Build & install

```bash
./build.sh            # compile and bundle into build/DeepSeek Harness.app
./build.sh --install  # bundle and install to ~/Applications
```

Open `~/Applications/DeepSeek Harness.app` (or drag it to the Dock / Launchpad).

## Configuration

The app reads configuration from UserDefaults (domain `local.deepseek-harness.desktop`):

```bash
defaults write local.deepseek-harness.desktop dsBin   "/path/to/dsh"   # dsh executable; default ~/.npm-global/bin/dsh
defaults write local.deepseek-harness.desktop dshHome "/path/to/.dsh"  # DSH_HOME; default ~/.dsh
defaults write local.deepseek-harness.desktop port    -int 3080        # web port; default 3080
defaults delete local.deepseek-harness.desktop dsBin                    # reset to default
```

## How it works

1. On launch, health-check `http://127.0.0.1:<port>/`;
2. Healthy → load the page directly (attach mode; quitting never touches the existing server). Otherwise → spawn `dsh web` as a child process and probe every second until ready (60 s timeout);
3. On quit, SIGTERM the server it started (SIGKILL after a 3 s grace period);
4. The UI renders in a WKWebView; external links open in the system browser.

## Layout

```
Sources/main.swift      # all source code (single file, no third-party deps)
Info.plist              # app manifest
assets/AppIcon.icns     # app icon (black whale)
assets/whale-black.svg  # icon source (DeepSeek icon from LobeHub lobe-icons, MIT, recolored black)
build.sh                # one-shot build/install script
.github/workflows/      # GitHub Actions: automated macOS build verification
```

## Icon

`assets/whale-black.svg` is derived from [LobeHub lobe-icons](https://github.com/lobehub/lobe-icons) (MIT), recolored black. The whale logo is a DeepSeek trademark and is used for local display only; replace it with your own artwork if you redistribute.

## License

[MIT](LICENSE)
