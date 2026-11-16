import AppKit
import mDESKCore

/// Petite fenêtre de mise à jour : version disponible (avec « Installer »), à jour, installation en cours ou échec.
/// Panneau non activant : une alerte automatique n'enlève jamais le focus à l'application en cours.
@MainActor
enum UpdateWindow {
    enum Content {
        case available(String, current: String)
        case installing(String)
        case upToDate(String)
        case failed(String)
    }

    private static var panel: NSPanel?
    private static let width: CGFloat = 320

    private final class Action: NSObject {
        let run: () -> Void
        init(_ run: @escaping () -> Void) { self.run = run }
        @objc func fire() { run() }
    }
    private static var actions: [Action] = []

    /// `activate` : vrai quand l'utilisateur vient de le demander (menu) ; faux pour une alerte automatique.
    static func show(_ content: Content, activate: Bool) {
        panel?.close()
        actions.removeAll()
        let title: String, text: String
        var install = false
        switch content {
        case .available(let v, let current): title = L("upd.availableTitle"); text = L("upd.availableText", v, current); install = true
        case .installing(let v): title = L("upd.availableTitle"); text = L("upd.availableText", v, Updater.shared.currentVersion)
        case .upToDate(let v): title = L("upd.uptodateTitle"); text = L("upd.uptodate", v)
        case .failed(let message): title = L("upd.failedTitle"); text = message
        }

        let icon = NSImageView(image: NSApp.applicationIconImage)
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 56).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 56).isActive = true

        func label(_ s: String, bold: Bool = false, secondary: Bool = false) -> NSTextField {
            let f = NSTextField(wrappingLabelWithString: s)
            let p = NSMutableParagraphStyle(); p.alignment = .center
            f.attributedStringValue = BrandStyle.colored(NSAttributedString(string: s, attributes: [
                .font: bold ? NSFont.boldSystemFont(ofSize: 14) : NSFont.systemFont(ofSize: 12), .paragraphStyle: p,
                .foregroundColor: secondary ? NSColor.secondaryLabelColor : NSColor.labelColor]))
            f.preferredMaxLayoutWidth = width
            f.isSelectable = false
            f.translatesAutoresizingMaskIntoConstraints = false
            f.widthAnchor.constraint(lessThanOrEqualToConstant: width).isActive = true
            return f
        }

        var views: [NSView] = [icon, label(title, bold: true), label(text)]
        let buttons = NSStackView()
        buttons.spacing = 10
        func button(_ key: String, primary: Bool, _ run: @escaping () -> Void) {
            let action = Action(run); actions.append(action)
            let b = NSButton(title: L(key), target: action, action: #selector(Action.fire))
            b.bezelStyle = .rounded
            if primary { b.keyEquivalent = "\r" }
            buttons.addArrangedSubview(b)
        }
        if install {
            button("upd.later", primary: false) { panel?.close() }
            button("upd.install", primary: true) {
                panel?.close()
                Task { await Updater.shared.install() }
            }
        } else if case .installing = content {
            // L'installation est déjà lancée : rien à cliquer.
        } else {
            button("upd.ok", primary: true) { panel?.close() }
        }
        if !buttons.arrangedSubviews.isEmpty { views.append(buttons) }

        let stack = NSStackView(views: views)
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 12
        stack.setCustomSpacing(6, after: views[1])
        stack.setCustomSpacing(18, after: views[2])
        stack.edgeInsets = NSEdgeInsets(top: 24, left: 24, bottom: 22, right: 24)
        stack.translatesAutoresizingMaskIntoConstraints = false
        stack.widthAnchor.constraint(equalToConstant: width + 48).isActive = true

        let p = NSPanel(contentRect: .zero, styleMask: [.titled, .closable, .nonactivatingPanel], backing: .buffered, defer: false)
        p.title = L("menu.checkUpdates")
        p.isReleasedWhenClosed = false
        p.level = .floating
        p.hidesOnDeactivate = false
        let contentView = NSView()
        contentView.addSubview(stack)
        NSLayoutConstraint.activate([
            stack.topAnchor.constraint(equalTo: contentView.topAnchor),
            stack.leadingAnchor.constraint(equalTo: contentView.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: contentView.bottomAnchor),
        ])
        p.contentView = contentView
        contentView.layoutSubtreeIfNeeded()
        contentView.layoutSubtreeIfNeeded()
        p.setContentSize(contentView.fittingSize)
        p.center()
        panel = p
        if activate { p.present() } else { p.orderFrontRegardless() }
    }
}
