import AppKit
import CryptoKit
import Foundation
import mDESKCore

/// Mise à jour depuis les releases GitHub : recherche quotidienne, téléchargement, vérification (empreinte SHA-256, signature
/// Developer ID de l'équipe, identifiant du paquet, version), remplacement puis relance. Jamais pendant une restauration.
/// SKYRIM_TOOLS_NO_UPDATE_CHECK=1 coupe la recherche automatique (essais) ; la commande du menu reste utilisable.
@MainActor
final class Updater {
    static let shared = Updater()

    enum State: Equatable {
        case idle, checking, upToDate
        case available(version: String)
        case downloading
        case failed(String)
    }

    static let repo = "starbudweiser/mDESK"
    static let teamID = "35KLMK53PN"                    // seule signature acceptée pour une mise à jour
    private let interval: TimeInterval = 24 * 3600

    private(set) var state: State = .idle
    private var release: UpdateRelease?
    private var timer: Timer?
    /// Appelé quand une version est trouvée et que l'installation automatique est désactivée (une fois par version).
    var onAvailable: ((String) -> Void)?
    /// Vrai quand une restauration est en cours ou programmée.
    var isBusy: () -> Bool = { false }

    var currentVersion: String { Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "0" }
    var autoUpdate: Bool {
        get { UserDefaults.standard.object(forKey: "autoUpdate") as? Bool ?? true }
        set { UserDefaults.standard.set(newValue, forKey: "autoUpdate") }
    }
    var availableVersion: String? { if case .available(let v) = state { return v }; return nil }
    private var autoCheckDisabled: Bool { ProcessInfo.processInfo.environment["SKYRIM_TOOLS_NO_UPDATE_CHECK"] != nil }

    /// Planificateur : un coup d'œil toutes les 30 minutes, une vraie recherche par jour au plus.
    func start() {
        guard !autoCheckDisabled else { return }
        timer = Timer.scheduledTimer(withTimeInterval: 1800, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.tick() }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 60) { [weak self] in self?.tick() }
    }

    private func tick() {
        let last = UserDefaults.standard.object(forKey: "updateLastCheck") as? Date ?? .distantPast
        if state == .idle || state == .upToDate, Date().timeIntervalSince(last) > interval {
            Task { await check(manual: false) }
        } else if autoUpdate, case .available = state, !isBusy() {
            Task { await install() }
        }
    }

    /// `manual` : demandé par l'utilisateur (le résultat est toujours annoncé) ; sinon recherche silencieuse.
    func check(manual: Bool) async {
        guard state != .checking, state != .downloading else { return }
        state = .checking
        do {
            var req = URLRequest(url: URL(string: "https://api.github.com/repos/\(Self.repo)/releases/latest")!)
            req.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
            req.timeoutInterval = 20
            let (data, resp) = try await URLSession.shared.data(for: req)
            guard (resp as? HTTPURLResponse)?.statusCode == 200,
                  let found = UpdateRelease.parse(data, app: Brand.name) else { throw UpdateError.noRelease }
            UserDefaults.standard.set(Date(), forKey: "updateLastCheck")
            guard VersionCompare.isNewer(found.version, than: currentVersion) else {
                state = .upToDate
                if manual { UpdateWindow.show(.upToDate(currentVersion), activate: true) }
                return
            }
            release = found
            state = .available(version: found.version)
            if autoUpdate {
                if manual { UpdateWindow.show(.installing(found.version), activate: true) }
                if !isBusy() { await install() }
                else if manual { UpdateWindow.show(.failed(L("upd.busy")), activate: true) }
            } else if manual {
                UpdateWindow.show(.available(found.version, current: currentVersion), activate: true)
            } else if UserDefaults.standard.string(forKey: "updateNotified") != found.version {
                UserDefaults.standard.set(found.version, forKey: "updateNotified")
                onAvailable?(found.version)
            }
        } catch {
            state = .failed(error.localizedDescription)
            if manual { UpdateWindow.show(.failed(error.localizedDescription), activate: true) }
        }
    }

    /// Télécharge la nouvelle version, la vérifie, puis remplace l'appli et la relance.
    func install() async {
        guard case .available = state, let release else { return }
        guard !isBusy() else { return }                                  // jamais pendant une restauration
        let target = Bundle.main.bundlePath
        guard FileManager.default.isWritableFile(atPath: (target as NSString).deletingLastPathComponent) else {
            state = .failed(UpdateError.readOnly.localizedDescription)
            UpdateWindow.show(.failed(UpdateError.readOnly.localizedDescription), activate: true)
            return
        }
        let previous = state
        state = .downloading
        let work = FileManager.default.temporaryDirectory.appendingPathComponent("mDESK-update-\(UUID().uuidString)")
        do {
            try FileManager.default.createDirectory(at: work, withIntermediateDirectories: true)
            let (tmp, resp) = try await URLSession.shared.download(from: release.zipURL)
            guard (resp as? HTTPURLResponse)?.statusCode == 200 else { throw UpdateError.download }
            let zip = work.appendingPathComponent("update.zip")
            try FileManager.default.moveItem(at: tmp, to: zip)
            if let shaURL = release.sha256URL {
                let (text, _) = try await URLSession.shared.data(from: shaURL)
                guard let expected = Checksum.parse(String(decoding: text, as: UTF8.self)),
                      Self.sha256(of: zip) == expected else { throw UpdateError.checksum }
            }
            let out = work.appendingPathComponent("out")
            try await Self.run("/usr/bin/ditto", ["-x", "-k", zip.path, out.path])
            let app = out.appendingPathComponent("\(Brand.name).app")
            try await Self.verify(app, current: currentVersion)
            guard !isBusy() else { state = previous; try? FileManager.default.removeItem(at: work); return }   // une restauration a démarré entre-temps
            try Self.swapAndRelaunch(new: app, work: work)
        } catch {
            state = .failed(error.localizedDescription)
            try? FileManager.default.removeItem(at: work)
            UpdateWindow.show(.failed(error.localizedDescription), activate: false)
        }
    }

    enum UpdateError: LocalizedError {
        case noRelease, download, checksum, badSignature, badVersion, readOnly
        var errorDescription: String? {
            switch self {
            case .noRelease: return L("upd.err.none")
            case .download: return L("upd.err.download")
            case .checksum: return L("upd.err.checksum")
            case .badSignature: return L("upd.err.signature")
            case .badVersion: return L("upd.err.version")
            case .readOnly: return L("upd.err.readonly")
            }
        }
    }

    private static func sha256(of url: URL) -> String? {
        guard let data = try? Data(contentsOf: url, options: .mappedIfSafe) else { return nil }
        return SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined()
    }

    /// La nouvelle appli doit être valide, signée par la même équipe, avoir le même identifiant et être plus récente.
    private static func verify(_ app: URL, current: String) async throws {
        try await run("/usr/bin/codesign", ["--verify", "--deep", "--strict", app.path])
        let info = try await run("/usr/bin/codesign", ["-dv", "--verbose=2", app.path])
        guard info.contains("TeamIdentifier=\(teamID)") else { throw UpdateError.badSignature }
        guard let plist = NSDictionary(contentsOf: app.appendingPathComponent("Contents/Info.plist")),
              plist["CFBundleIdentifier"] as? String == Bundle.main.bundleIdentifier,
              let v = plist["CFBundleShortVersionString"] as? String,
              VersionCompare.isNewer(v, than: current) else { throw UpdateError.badVersion }
    }

    /// Un petit script détaché attend la fin de l'appli, remplace le paquet puis relance la nouvelle version (sans la mettre au premier plan).
    private static func swapAndRelaunch(new: URL, work: URL) throws {
        let target = Bundle.main.bundlePath
        let script = work.appendingPathComponent("swap.sh")
        let body = """
        #!/bin/sh
        while kill -0 \(ProcessInfo.processInfo.processIdentifier) 2>/dev/null; do sleep 0.3; done
        rm -rf "\(target)" && /usr/bin/ditto "\(new.path)" "\(target)" && /usr/bin/open -g "\(target)"
        rm -rf "\(work.path)"
        """
        try body.write(to: script, atomically: true, encoding: .utf8)
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/bin/sh")
        p.arguments = [script.path]
        p.standardOutput = FileHandle.nullDevice; p.standardError = FileHandle.nullDevice
        try p.run()
        NSApp.terminate(nil)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { exit(0) }     // terminate() peut rester sans effet derrière une fenêtre modale
    }

    @discardableResult
    private static func run(_ exe: String, _ args: [String]) async throws -> String {
        try await withCheckedThrowingContinuation { cont in
            DispatchQueue.global().async {
                let p = Process(), pipe = Pipe()
                p.executableURL = URL(fileURLWithPath: exe); p.arguments = args
                p.standardOutput = pipe; p.standardError = pipe
                do { try p.run() } catch { cont.resume(throwing: error); return }
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                p.waitUntilExit()
                let text = String(decoding: data, as: UTF8.self)
                if p.terminationStatus == 0 { cont.resume(returning: text) }
                else { cont.resume(throwing: exe.hasSuffix("codesign") ? UpdateError.badSignature : UpdateError.download) }
            }
        }
    }
}
