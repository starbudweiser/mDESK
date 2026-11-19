import AppKit
import mDESKCore
import SwiftUI

/// Aplat de couleur dynamique (suit le thème clair/sombre), pour le fond et la barre de titre de la fenêtre.
private final class FillView: NSView {
    var fill: NSColor { didSet { needsDisplay = true } }
    init(_ fill: NSColor) { self.fill = fill; super.init(frame: .zero) }
    required init?(coder: NSCoder) { fatalError() }
    override func draw(_ dirtyRect: NSRect) { fill.setFill(); dirtyRect.fill() }
}

/// Fenêtre « À propos » : version, auteurs, licence. Textes dans les fichiers de langue (L).
/// Fenêtre à nous plutôt que le panneau standard, dont la zone de texte a une hauteur fixe qui rogne les textes longs.
@MainActor
enum About {
    private static var window: NSWindow?

    private static let sideMargin: CGFloat = 28
    private static let textWidth: CGFloat = 300

    /// Centrage (règle Socle « Fenêtres secondaires centrées ») : appli à fenêtres (Dock) → au centre de sa fenêtre visible ;
    /// appli de barre de menus sans fenêtre (`.accessory`) → au centre de l'écran du pointeur, jamais sur une fenêtre de fond.
    private static func centerWindow(_ w: NSWindow) {
        if NSApp.activationPolicy() == .regular,
           let host = NSApp.windows.first(where: { $0 !== w && $0.isVisible && $0.canBecomeMain }) {
            let f = host.frame
            w.setFrameOrigin(NSPoint(x: f.midX - w.frame.width / 2, y: f.midY - w.frame.height / 2))
            return
        }
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first(where: { NSMouseInRect(mouse, $0.frame, false) }) ?? NSScreen.main ?? NSScreen.screens[0]
        let v = screen.visibleFrame
        w.setFrameOrigin(NSPoint(x: v.midX - w.frame.width / 2, y: v.midY - w.frame.height / 2))
    }

    static func show() {
        if window == nil { window = makeWindow() }
        if let w = window { centerWindow(w) }
        window?.present()
    }

    private static func label(_ text: String, size: CGFloat = 12, bold: Bool = false, secondary: Bool = false) -> NSTextField {
        let field = NSTextField(wrappingLabelWithString: text)
        let font = bold ? NSFont.boldSystemFont(ofSize: size) : NSFont.systemFont(ofSize: size)
        let paragraph = NSMutableParagraphStyle()
        paragraph.alignment = .center
        // Lettre minuscule du nom en couleur (règle Socle « Nom de l'appli »)
        field.attributedStringValue = BrandStyle.colored(NSAttributedString(string: text, attributes: [
            .font: font, .paragraphStyle: paragraph,
            .foregroundColor: secondary ? NSColor(Socle.C.textMuted) : (bold ? NSColor(Socle.C.textStrong) : NSColor(Socle.C.text))]))
        field.alignment = .center
        field.preferredMaxLayoutWidth = textWidth
        field.isSelectable = false
        field.translatesAutoresizingMaskIntoConstraints = false
        field.widthAnchor.constraint(lessThanOrEqualToConstant: textWidth).isActive = true
        return field
    }

    private static func makeWindow() -> NSWindow {
        let info = Bundle.main.infoDictionary ?? [:]
        let version = info["CFBundleShortVersionString"] as? String ?? "?"
        let build = info["CFBundleVersion"] as? String ?? "?"

        let icon = NSImageView(image: NSApp.applicationIconImage)
        icon.imageScaling = .scaleProportionallyUpOrDown
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.widthAnchor.constraint(equalToConstant: 84).isActive = true
        icon.heightAnchor.constraint(equalToConstant: 84).isActive = true

        let views: [NSView] = [
            icon,
            label(Brand.name, size: 17, bold: true),
            label(L("about.version", version, build), secondary: true),
            label(L("about.collection"), secondary: true),
            label(L("about.tagline")),
            label(L("about.authors"), bold: true),
            label(L("about.license")),
            label(L("about.disclaimer"), secondary: true),
            label(L("about.credit"), secondary: true),
        ]
        let stack = NSStackView(views: views)
        stack.orientation = .vertical
        stack.alignment = .centerX
        stack.spacing = 12
        stack.setCustomSpacing(6, after: views[1])
        stack.setCustomSpacing(2, after: views[2])
        stack.setCustomSpacing(18, after: views[3])
        stack.edgeInsets = NSEdgeInsets(top: 28, left: sideMargin, bottom: 28, right: sideMargin)
        stack.translatesAutoresizingMaskIntoConstraints = false
        // Largeur fixée : le texte garde ses marges de chaque côté quelle que soit la langue.
        stack.widthAnchor.constraint(equalToConstant: textWidth + 2 * sideMargin).isActive = true

        let window = NSWindow(contentRect: .zero, styleMask: [.titled, .closable, .fullSizeContentView], backing: .buffered, defer: false)
        window.title = L("about.menu")
        window.isReleasedWhenClosed = false
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.standardWindowButton(.miniaturizeButton)?.isHidden = true   // bouton de fermeture seul
        window.standardWindowButton(.zoomButton)?.isHidden = true
        window.backgroundColor = NSColor(Socle.C.bg)
        let content = FillView(NSColor(Socle.C.bg))
        // Barre de titre Socle : 30px `surfaceRaised`, filet `border` dessous
        let bar = FillView(NSColor(Socle.C.surfaceRaised)); bar.translatesAutoresizingMaskIntoConstraints = false
        let rule = FillView(NSColor(Socle.C.border)); rule.translatesAutoresizingMaskIntoConstraints = false
        content.addSubview(stack); content.addSubview(bar); bar.addSubview(rule)
        NSLayoutConstraint.activate([
            bar.topAnchor.constraint(equalTo: content.topAnchor), bar.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            bar.trailingAnchor.constraint(equalTo: content.trailingAnchor), bar.heightAnchor.constraint(equalToConstant: 30),
            rule.leadingAnchor.constraint(equalTo: bar.leadingAnchor), rule.trailingAnchor.constraint(equalTo: bar.trailingAnchor),
            rule.bottomAnchor.constraint(equalTo: bar.bottomAnchor), rule.heightAnchor.constraint(equalToConstant: 1),
            stack.topAnchor.constraint(equalTo: bar.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: content.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: content.trailingAnchor),
            stack.bottomAnchor.constraint(equalTo: content.bottomAnchor),
        ])
        window.contentView = content
        content.layoutSubtreeIfNeeded()
        content.layoutSubtreeIfNeeded() // les textes à la ligne ne connaissent leur hauteur qu'après une première passe
        window.setContentSize(content.fittingSize)
        return window
    }
}
