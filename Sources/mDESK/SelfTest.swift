#if MDESK_SELFTEST
import AppKit
import mDESKCore

/// Pilotage sans menu pour les essais réels (build `SELFTEST=1 ./build.sh` uniquement, absent des builds normaux).
/// `mDESK --selftest <dossier de données> <commande>`, le dossier isole les essais des vraies données.
@MainActor
enum SelfTest {
    static func runIfRequested(_ arguments: [String]) -> Bool {
        guard arguments.count >= 4, arguments[1] == "--selftest" else { return false }
        NSApplication.shared.setActivationPolicy(.accessory) // comme l'app réelle
        let store = ArrangementStore(directory: URL(fileURLWithPath: arguments[2], isDirectory: true))
        do {
            try store.load()
        } catch {
            print("ÉCHEC chargement : \(error.localizedDescription)")
            exit(1)
        }
        let controller = Controller(store: store)

        switch arguments[3] {
        case "status":
            print("accessibilite=\(WindowBridge.isTrusted)")
            print("ecrans=\(Displays.current().count) arrangements=\(store.data.arrangements.count)")
        case "request-accessibility":
            WindowBridge.requestTrust()
        case "memorize":
            let id = controller.activeArrangement?.id
            let (parts, app) = parse(arguments.count > 4 ? arguments[4] : "all")
            printReport(controller.memorize(arrangementID: id, newName: id == nil ? "Essai" : nil, purgeMissing: false,
                                            parts: parts, onlyApp: app))
            print(controller.lastStatus)
        case "restore":
            guard let active = controller.activeArrangement else {
                print("ÉCHEC : aucun arrangement actif")
                exit(1)
            }
            let (parts, app) = parse(arguments.count > 4 ? arguments[4] : "all")
            printReport(controller.restore(active, parts: parts, onlyApp: app))
            print(controller.lastStatus)
        case "hide":
            let seconds = arguments.count > 4 ? Double(arguments[4]) ?? 5 : 5
            controller.hider.hide()
            print("masque=\(controller.hider.isHidden)")
            RunLoop.main.run(until: Date().addingTimeInterval(seconds))
            controller.hider.show()
            print("masque=\(controller.hider.isHidden)")
        case "auto":
            // Passe par les mêmes temporisation et sélection que les événements système.
            controller.scheduleAutoRestore(reason: "essai", after: 0.2)
            controller.scheduleAutoRestore(reason: "essai-2", after: 0.5)
            RunLoop.main.run(until: Date().addingTimeInterval(arguments.count > 4 ? Double(arguments[4]) ?? 8 : 8))
            print(controller.lastStatus)
        case "about":
            About.show()
            RunLoop.main.run(until: Date().addingTimeInterval(arguments.count > 4 ? Double(arguments[4]) ?? 4 : 4))
        case "icontest":
            // Déplace N icônes (chemin lent), puis mesure le « clic » : restauration des icônes mal placées.
            let n = arguments.count > 4 ? Int(arguments[4]) ?? 10 : 10
            guard let active = controller.activeArrangement else { print("ÉCHEC : aucun arrangement actif"); exit(1) }
            let displays = Displays.current()
            do {
                let bridge = try FinderBridge()
                let target = active.desktopIcons
                let shifted = Array(target.prefix(n)).map { icon -> DesktopIcon in
                    var moved = icon
                    moved.position = NormalizedPoint(x: min(max(icon.position.x + 0.05, 0.02), 0.95), y: min(max(icon.position.y + 0.07, 0.02), 0.95))
                    return moved
                }
                func timed<T>(_ label: String, _ block: () throws -> T) rethrows -> T {
                    let t = Date(); let r = try block()
                    print("  \(label) : \(Int(Date().timeIntervalSince(t) * 1000)) ms"); return r
                }
                _ = timed("lecture Bureau") { try? bridge.readDesktop(displays: displays) }
                _ = timed("lecture Bureau (2e)") { try? bridge.readDesktop(displays: displays) }
                _ = timed("déplacer 3 icônes") { try? bridge.restoreDesktop(Array(shifted.prefix(3)), displays: displays) }
                var worst = 0.0
                for run in 1...2 {
                    _ = try bridge.restoreDesktop(shifted, displays: displays)
                    RunLoop.main.run(until: Date().addingTimeInterval(2)) // laisse le Finder au repos : l'état d'avant le clic
                    let start = Date()
                    _ = controller.restore(active, parts: .icons)
                    let ms = Date().timeIntervalSince(start) * 1000
                    print("essai \(run) : \(Int(ms)) ms")
                    worst = max(worst, ms)
                }
                let after = Dictionary(try bridge.readDesktop(displays: displays).map { ($0.name, $0) }, uniquingKeysWith: { a, _ in a })
                var wrong = 0
                for icon in target {
                    guard let now = after[icon.name], let display = Geometry.targetDisplay(id: icon.displayID, in: displays) else { continue }
                    let a = Geometry.denormalize(now.position, in: display.frame), b = Geometry.denormalize(icon.position, in: display.frame)
                    if hypot(a.x - b.x, a.y - b.y) >= 3 { wrong += 1 }
                }
                let limit = n <= 10 ? 300.0 : 600.0 // « instantané au clic » : seuils mesurés avec marge
                let ok = wrong == 0 && worst <= limit
                print("icônes déplacées=\(n) mal placées après=\(wrong) pire clic=\(Int(worst)) ms (seuil \(Int(limit)) ms) → \(ok ? "OK" : "ÉCHEC")")
                if !ok { exit(1) }
            } catch {
                print("ÉCHEC : \(error.localizedDescription)")
                exit(1)
            }
        case "events":
            runEvents(directory: store.directory)
        default:
            print("ÉCHEC : commande inconnue")
            exit(1)
        }
        return true
    }

    /// Lance l'app complète puis lui envoie les notifications système réelles, dans le seul processus de l'essai.
    private static func runEvents(directory: URL) -> Never {
        let delegate = AppDelegate()
        delegate.dataDirectoryOverride = directory
        NSApplication.shared.delegate = delegate
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 1_000_000_000)
            NotificationCenter.default.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
            try? await Task.sleep(nanoseconds: 500_000_000)
            NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.didWakeNotification, object: nil)
            try? await Task.sleep(nanoseconds: 6_000_000_000)
            print(delegate.controller?.lastStatus ?? "pas de contrôleur")
            let menu = NSMenu()
            delegate.menuNeedsUpdate(menu)
            print("menu : \(menu.items.map(\.title).filter { !$0.isEmpty }.joined(separator: " | "))")
            exit(0)
        }
        NSApplication.shared.run()
        exit(1)
    }

    /// `all`, `icons`, `windows` ou `app:<identifiant de paquet>`.
    private static func parse(_ text: String) -> (Parts, String?) {
        if text == "icons" { return (.icons, nil) }
        if text == "windows" { return (.windows, nil) }
        if text.hasPrefix("app:") { return (.appWindows, String(text.dropFirst(4))) }
        return (.all, nil)
    }

    private static func printReport(_ report: Controller.Report) {
        print("fait : \(report.done.joined(separator: ", "))")
        for problem in report.problems { print("problème : \(problem)") }
    }
}
#endif
