import AppKit
import ServiceManagement

@main
enum mDESKMain {
    @MainActor
    static func main() {
        #if MDESK_SELFTEST
        if SelfTest.runIfRequested(CommandLine.arguments) { return }
        #endif
        // Après un changement d'emplacement ou de nom de l'appli : réenregistre l'ouverture à la connexion si elle est active.
        if CommandLine.arguments.contains("--refresh-login-item") {
            let service = SMAppService.mainApp
            if service.status == .enabled { try? service.unregister(); try? service.register() }
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
