import AppKit
import ServiceManagement

@main
enum mDESKMain {
    @MainActor
    static func main() {
        #if MDESK_SELFTEST
        if SelfTest.runIfRequested(CommandLine.arguments) { return }
        #endif
        // `--login-item on|off` : (dés)enregistre l'ouverture à la connexion sans lancer l'appli (changement de nom, d'identifiant…).
        if let i = CommandLine.arguments.firstIndex(of: "--login-item"), i + 1 < CommandLine.arguments.count {
            let service = SMAppService.mainApp
            if CommandLine.arguments[i + 1] == "on" { try? service.register() } else { try? service.unregister() }
            print("ouverture à la connexion : \(service.status == .enabled ? "active" : "inactive")")
            return
        }
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory) // app de barre de menus, sans icône dans le Dock
        withExtendedLifetime(delegate) {
            app.run()
        }
    }
}
