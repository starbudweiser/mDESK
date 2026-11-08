#!/bin/bash
# Version distribuable de mDESK : compile, installe, puis signe Developer ID (runtime renforcé + entitlement Apple Events),
# notarise et agrafe avec les outils communs (profil notarytool « Applications »). Résultat : _tools/notarized/mDESK.zip.
set -euo pipefail
cd "$(dirname "$0")"

TOOLS="/Volumes/SKYRIM/TOOLS/MAC/_tools"
INSTALL_DIR="${INSTALL_DIR:-$HOME/Applications/Applications Personnelles}"

INSTALL_DIR="$INSTALL_DIR" ./build.sh
APP_ENTITLEMENTS="$(pwd)/Resources/mDESK.entitlements" "$TOOLS/notarize_app.sh" "$INSTALL_DIR/mDESK.app"
