#!/bin/bash
# Version distribuable de mDESK : compile, signe Developer ID (runtime renforcé + entitlement Apple Events), notarise et agrafe
# avec les outils communs (profil notarytool « Applications »), puis publie la release GitHub :
#   mDESK-<version>-macOS-arm64.zip + .sha256 (format que cherche la mise à jour automatique, Sources/mDESKCore/UpdateLogic.swift).
# Usage : ./release.sh [fichier-de-notes.md]   — la version vient de CFBundleShortVersionString (Resources/Info.plist).
# Sans fichier de notes : release_notes.md à la racine s'il existe (notes en 4 langues, voir les marqueurs de la release 1.0.1).
# La copie installée sur ce Mac n'est pas touchée : la compilation passe par un dossier temporaire.
set -euo pipefail
cd "$(dirname "$0")"

TOOLS="/Volumes/SKYRIM/TOOLS/MAC/_tools"
VERSION="$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' Resources/Info.plist)"
TAG="v$VERSION"
DIST="$PWD/dist"
NOTES_FILE="${1:-release_notes.md}"
[ -f "$NOTES_FILE" ] || { echo "Notes de version introuvables : $NOTES_FILE" >&2; exit 1; }
git diff --quiet && git diff --cached --quiet || { echo "Modifications non commitées : commiter avant la release." >&2; exit 1; }
! git rev-parse "$TAG" >/dev/null 2>&1 || { echo "La version $TAG existe déjà." >&2; exit 1; }

BUILD_DIR="$(mktemp -d)"
trap 'rm -rf "$BUILD_DIR"' EXIT
INSTALL_DIR="$BUILD_DIR" ./build.sh
rm -rf "$DIST"
DIST="$DIST" APP_ENTITLEMENTS="$(pwd)/Resources/mDESK.entitlements" "$TOOLS/notarize_app.sh" "$BUILD_DIR/mDESK.app"

ZIP="$DIST/mDESK-$VERSION-macOS-arm64.zip"
mv "$DIST/mDESK.zip" "$ZIP"
( cd "$DIST" && shasum -a 256 "$(basename "$ZIP")" > "$(basename "$ZIP").sha256" )
{ cat "$NOTES_FILE"; printf '\n---\nSHA-256 `%s` :\n\n```\n%s\n```\n' "$(basename "$ZIP")" "$(cat "$ZIP.sha256")"; } > "$DIST/notes.md"

git tag "$TAG" && git push -q origin "$TAG"
gh release create "$TAG" "$ZIP" "$ZIP.sha256" --title "mDESK $VERSION" --notes-file "$DIST/notes.md"
echo "Release publiée : $(gh release view "$TAG" --json url -q .url)"
