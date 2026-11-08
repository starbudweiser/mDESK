// swift-tools-version:5.10
import PackageDescription

let package = Package(
    name: "mDESK",
    platforms: [.macOS(.v14)],
    products: [
        // Le binaire (et donc le paquet .app) porte le nom de l'appli, règle Socle « Nom de l'appli ».
        .executable(name: "mDESK", targets: ["mDESK"]),
    ],
    targets: [
        // Logique pure (sans AppKit) : modèles, géométrie, fusion, persistance. Testable.
        .target(name: "mDESKCore"),
        // Application barre de menus : Finder (AppleScript), fenêtres (Accessibilité), masquage.
        .executableTarget(name: "mDESK", dependencies: ["mDESKCore"]),
        .testTarget(name: "mDESKCoreTests", dependencies: ["mDESKCore"]),
    ]
)
