<p align="center"><img src="assets/icon.png" width="128" alt="mDESK"></p>

# mDESK

[![Listed on OpenMacApps](https://openmacapps.com/badge.svg)](https://openmacapps.com/apps/mdesk/) [![Latest release](https://img.shields.io/github/v/release/starbudweiser/mDESK)](https://github.com/starbudweiser/mDESK/releases/latest) [![License: MIT](https://img.shields.io/badge/license-MIT-blue)](LICENSE)

A menu-bar app for macOS that remembers and restores where things sit on your screens: **desktop icons** (like Desktop Icon Manager) and **application windows** (like Stay), per display combination.

🇬🇧 English · 🇫🇷 [Français](#français)

## About

mDESK is a personal tool by **Starbudweiser & Claude Code (Anthropic)**, released under the MIT license. It merges the ideas of [Desktop Icon Manager](https://www.parker9.com/desktopIconManager4.html) and [Stay](https://cordlessdog.com/stay/) and is not affiliated with their authors. It is provided as is, without warranty. The same information is available in the app itself: menu bar icon › *About mDESK*.

## Features

- **Desktop icons**: save and restore their positions (instantly, only the icons that moved), or hide them.
- **Windows**: save and restore the position of Finder windows (never reopened if closed) and application windows, chosen app by app.
- **Several arrangements**, picked automatically from the connected displays.
- **Nothing automatic by default**; restoring on display change, wake or launch are opt-in options.
- Available in English, French, Spanish and Italian (follows the system language).

## Install

**[Download the latest notarized release](https://github.com/starbudweiser/mDESK/releases/latest)**, unzip it and move **mDESK.app** to your Applications folder. Requires **macOS 14 Sonoma** or later.

### Requirements

macOS 14 or later. On first use macOS asks for two permissions: Automation (to control the Finder) and Accessibility (to move application windows).

## Build

```bash
swift test        # unit tests
./build.sh        # builds, signs and installs mDESK.app
./release.sh      # Developer ID signature, archive and notarization (see the script header)
```

Data is kept in `~/Library/Application Support/mDESK/arrangements.json`.

## Languages

English, French, Spanish and Italian. The app follows your Mac's preferred language automatically (English if it is none of these four).

## Support

Bug reports and suggestions: [GitHub Issues](https://github.com/starbudweiser/mDESK/issues).

## License

MIT, © 2026 Starbudweiser. See [LICENSE](LICENSE).

---

## Français

Appli de barre de menus pour macOS qui mémorise et restaure la place des éléments sur vos écrans : **icônes du bureau** (comme Desktop Icon Manager) et **fenêtres des applis** (comme Stay), par combinaison d'écrans.

- Icônes du bureau : enregistrer et restaurer leurs positions, ou les masquer.
- Fenêtres : position des fenêtres du Finder et des applis choisies.
- Plusieurs dispositions, choisies d'après les écrans branchés ; rien d'automatique par défaut.
- Au premier usage, macOS demande deux autorisations : Automatisation (Finder) et Accessibilité (déplacer les fenêtres).

Installation : téléchargez la [dernière version notarisée](https://github.com/starbudweiser/mDESK/releases/latest), décompressez-la et placez **mDESK.app** dans Applications (macOS 14 Sonoma ou plus récent).

Interface en français, anglais, espagnol et italien, choisie d'après la langue du Mac (anglais sinon). Licence MIT, © 2026 Starbudweiser. Questions et bugs : [Issues GitHub](https://github.com/starbudweiser/mDESK/issues).
