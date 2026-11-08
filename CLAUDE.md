# mDESK — contexte projet

App macOS personnelle de barre de menus qui combine **Desktop Icon Manager** (positions des icônes du Bureau et des fenêtres Finder, arrangements multiples, positions relatives à l'écran) et **Stay** (positions des fenêtres d'applications par combinaison d'écrans, restauration automatique).

Références :
- DIM : https://www.parker9.com/desktopIconManager4.html — source : https://github.com/com-entonos/Desktop-Icon-Manager
- Stay : https://cordlessdog.com/stay/

## Environnement
- Mac Studio M5 Max, macOS 27.2, Xcode 27.2, Swift 6.4 (package en tools-version 5.10, mode de langage Swift 5).
- Écrans : principal 3440×1440 (origine 0,0) ; secondaire 1080×1920 portrait à x=3440, y=49.
- Cible minimale : macOS 14.
- Langage : Swift uniquement (option Rust étudiée et écartée le 31/10/2026).

## Architecture
- `Sources/mDESKCore` : logique pure sans AppKit (modèles, géométrie, fusion, sélection, persistance JSON). **Toute logique testable va ici.**
- `Sources/mDESK` : app AppKit (`LSUIElement`)
  - `FinderBridge` : AppleScript (NSAppleScript, thread principal) ; les données passent en paramètres de gestionnaires, jamais concaténées dans le source.
  - `WindowBridge` : API Accessibilité (AXUIElement) pour les fenêtres d'apps (le Finder est exclu, géré par AppleScript).
  - `IconHider` : masquage par fenêtres de fond d'écran au niveau `desktopIconWindow + 1` (aucun réglage Finder modifié).
  - `Controller` : mémoriser / restaurer / restauration automatique (temporisée).
  - `AppDelegate` : menu de barre de menus, événements (écrans, réveil, déverrouillage), ouverture à la connexion (SMAppService).
- Données : `~/Library/Application Support/mDESK/arrangements.json` (écriture atomique + `.bak`, fichier illisible mis de côté, version plus récente jamais écrasée).

## Faits vérifiés sur ce Mac
- `desktop position` du Finder = coordonnées Quartz globales (bounds du Bureau = union des écrans, 0,0,4520,1969).
- `every item of desktop` inclut les disques montés.
- Finder : `repeat with w in (every Finder window)` parcourt les éléments du dossier affiché, pas les fenêtres ; toujours boucler par index.
- Un écran sur un Space plein écran n'affiche pas le Bureau : la fenêtre d'icônes du Finder et celle du masquage y sont hors écran.

## Commandes
- Compiler : `swift build`
- Tests : `swift test` (21 tests XCTest, tous verts au 31/10/2026)
- App : `./build.sh` → `~/Applications/Applications Personnelles/mDESK.app` (déplacée, pas de copie dans build/) (signé via `sign_app.sh`, certificat local stable ; `SIGN_IDENTITY=<SHA-1> ./build.sh` pour un autre certificat)
- Langues : fr, en, es, it, mêmes clés partout, anglais si la langue du système est autre. Textes dans `tools/strings_table.py` ; `python3 tools/gen_strings.py` génère `Resources/<langue>.lproj/{Localizable,InfoPlist}.strings` (copiés par `build.sh`). Dans le code : `L("clé", args)` (`%@`, `%ld`), jamais de texte en dur ; `LocalizationTests` vérifie clés, formats et usage. Essai : `mDESK --selftest <dir> events -AppleLanguages "(es)"`.
- À propos : `About.swift`, licence MIT dans `LICENSE`, auteurs « Starbudweiser & Claude Code ».
- Icône : `assets/make_icon.py` (PyQt6, couleurs Socle) produit `assets/icon.icns` ; `build.sh` la copie dans l'app.
- Essais réels : `SELFTEST=1 ./build.sh` (reste dans build/), puis `build/mDESK.app/Contents/MacOS/mDESK --selftest <dossier de données> status|memorize|restore|hide|auto|events` (code absent des builds normaux)

## Points ouverts
- **Notarisation** (faite le 01/11/2026, refaite via les outils communs le 08/11/2026) : `./release.sh` compile, installe, puis `_tools/notarize_app.sh` signe en Developer ID (runtime renforcé, entitlement `Resources/mDESK.entitlements` = Apple Events), notarise (profil notarytool « Applications »), agrafe ; résultat `_tools/notarized/mDESK.zip`. L'identité Developer ID `B675FD78…` du trousseau « session » échoue (`errSecInternalComponent`) ; ne jamais réinitialiser un trousseau sans accord explicite.
- Essais réels du 31/10/2026 (via `--selftest memorize|restore all|icons|windows|app:<bundle>`) : mémoriser et restaurer séparément icônes (type DIM) et fenêtres (type Stay), une seule app, exclusion « ne pas déplacer », fenêtres Finder fermées jamais rouvertes, masquage, observateurs d'événements. OK.
- Pas encore testé : demandes d'autorisation de l'app seule (le shell transmet les siennes), vrais événements écran / réveil / déverrouillage, clics sur le menu, ouverture à la connexion, masquage visible sur l'écran portrait (il était en plein écran).
- Décidé le 31/10/2026 : aucune restauration automatique par défaut (écrans, réveil, ouverture : options désactivées à la Stay) ; fenêtres Finder fermées jamais rouvertes ; choix app par app (`excludedApps`) ; icônes et fenêtres mémorisées / restaurées séparément ou ensemble.

## Préférences de travail de l'utilisateur
- Réponses en français, structurées (Objectif, Analyse, Fichiers, Code, Validation, Limites, Suite).
- Changements minimaux et réversibles ; tests de non-régression pour la logique ; rapporter les commandes réellement exécutées et leurs résultats.
- Ne rien présenter comme fonctionnel sans l'avoir vérifié.

- Retour des icônes : instantané, comme DIM (essayé puis abandonné le 31/10/2026 : copies animées par Core Animation, trop fragiles à rendre identiques au Finder). Seules les icônes pas déjà en place sont déplacées (le Finder met ~17 ms par icône).
## Nom de l'appli (règle Socle « Nom de l'appli »)
- Nom : **mDESK** (majuscules, « m » minuscule ; ex-DeskStay puis DeSKSTAY, renommé le 08/11/2026). Le « m » est coloré (ambre du logo, `BrandStyle.color`) dans la fenêtre À propos et les dialogues (`BrandStyle.apply(to:)`) ; texte normal dans les menus déroulants (règle du 04/11/2026), la barre de titre et les notifications système. `Brand.name` / `Brand.lowercaseRanges` (mDESKCore) portent la règle, testée dans `BrandTests`.
- Paquet `mDESK.app`, binaire `mDESK`, cibles SwiftPM `mDESK` / `mDESKCore` / `mDESKCoreTests`, dépôt GitHub `starbudweiser/mDESK`, dossier du projet `/Volumes/OWC 6To/TAF/DEV/mDESK`, données `~/Library/Application Support/mDESK` (l'ancien dossier `DeskStay` est déplacé au premier lancement). Reste inchangé : l'identifiant de paquet `com.stephan.deskstay` (garde les autorisations macOS et l'ouverture à la connexion). `mDESK --refresh-login-item` réenregistre l'ouverture à la connexion après un changement de nom ou d'emplacement.
- Publication : `./release.sh` (outils communs `_tools/notarize_app.sh`, profil « Applications ») ; `_tools/release_app.sh mDESK` pour une release GitHub.
