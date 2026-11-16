import Foundation

/// Compare deux numéros de version « 1.2.3 » (un éventuel « v » initial est ignoré).
public enum VersionCompare {
    public static func parts(_ v: String) -> [Int] {
        v.trimmingCharacters(in: CharacterSet(charactersIn: "vV ")).split(separator: ".").map { Int($0.filter(\.isNumber)) ?? 0 }
    }

    public static func isNewer(_ a: String, than b: String) -> Bool {
        let x = parts(a), y = parts(b)
        for i in 0..<max(x.count, y.count) {
            let p = i < x.count ? x[i] : 0, q = i < y.count ? y[i] : 0
            if p != q { return p > q }
        }
        return false
    }
}

/// Release GitHub retenue pour une mise à jour : version, archive à télécharger et empreinte SHA-256 si publiée.
public struct UpdateRelease: Equatable {
    public let version: String
    public let zipURL: URL
    public let sha256URL: URL?

    public init(version: String, zipURL: URL, sha256URL: URL?) {
        self.version = version; self.zipURL = zipURL; self.sha256URL = sha256URL
    }

    /// Lit la réponse de `GET /repos/<dépôt>/releases/latest`. Les releases brouillon ou préversion sont ignorées.
    /// Archive attendue : `<App>-<version>-macOS-arm64.zip` (format de release.sh), à défaut le seul `.zip` de la release ;
    /// empreinte : le fichier `<archive>.sha256` voisin.
    public static func parse(_ data: Data, app: String) -> UpdateRelease? {
        guard let json = (try? JSONSerialization.jsonObject(with: data)) as? [String: Any],
              let tag = json["tag_name"] as? String,
              (json["draft"] as? Bool) != true, (json["prerelease"] as? Bool) != true else { return nil }
        let version = tag.trimmingCharacters(in: CharacterSet(charactersIn: "vV "))
        let assets = (json["assets"] as? [[String: Any]] ?? []).compactMap { a -> (String, URL)? in
            guard let name = a["name"] as? String, let s = a["browser_download_url"] as? String, let url = URL(string: s) else { return nil }
            return (name, url)
        }
        let zips = assets.filter { $0.0.hasSuffix(".zip") }
        let expected = "\(app)-\(version)-macOS-arm64.zip"
        guard let zip = zips.first(where: { $0.0 == expected })
                ?? zips.first(where: { $0.0.hasPrefix(app) && $0.0.contains("macOS-arm64") })
                ?? zips.first(where: { $0.0.hasPrefix(app) })
                ?? (zips.count == 1 ? zips[0] : nil) else { return nil }
        let sha = assets.first { $0.0 == zip.0 + ".sha256" }?.1
        return UpdateRelease(version: version, zipURL: zip.1, sha256URL: sha)
    }
}

public enum Checksum {
    /// Extrait l'empreinte hexadécimale (64 caractères) d'un fichier `.sha256` (« <empreinte>  <nom> » ou empreinte seule).
    public static func parse(_ text: String) -> String? {
        let first = text.split(whereSeparator: \.isWhitespace).first.map(String.init)?.lowercased()
        guard let first, first.count == 64, first.allSatisfy(\.isHexDigit) else { return nil }
        return first
    }
}
