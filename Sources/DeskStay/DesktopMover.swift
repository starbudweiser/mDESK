import Carbon
import Foundation

/// Déplacement des icônes du Bureau par événements Apple bruts, envoyés en parallèle au Finder.
/// Le Finder met ~17 ms par icône en AppleScript, un envoi à la fois ; plusieurs connexions simultanées divisent
/// le temps total par ~2 (mesuré : 49 icônes, 836 ms en série, 435 ms à trois). Sûr hors du thread principal.
enum DesktopMover {
    private static let workers = 3

    private static func code(_ s: String) -> OSType {
        s.utf8.reduce(0) { ($0 << 8) | OSType($1) }
    }

    private static func specifier(want: String, form: String, data: NSAppleEventDescriptor,
                                  container: NSAppleEventDescriptor) -> NSAppleEventDescriptor? {
        let record = NSAppleEventDescriptor.record()
        record.setDescriptor(NSAppleEventDescriptor(typeCode: code(want)), forKeyword: code("want"))
        record.setDescriptor(NSAppleEventDescriptor(enumCode: code(form)), forKeyword: code("form"))
        record.setDescriptor(data, forKeyword: code("seld"))
        record.setDescriptor(container, forKeyword: code("from"))
        return record.coerce(toDescriptorType: typeObjectSpecifier)
    }

    /// « set desktop position of item <name> of desktop to {x, y} »
    private static func event(name: String, x: Int, y: Int) -> NSAppleEventDescriptor? {
        guard let desktop = specifier(want: "prop", form: "prop", data: NSAppleEventDescriptor(typeCode: code("desk")),
                                      container: .null()),
              let item = specifier(want: "cobj", form: "name", data: NSAppleEventDescriptor(string: name), container: desktop),
              let property = specifier(want: "prop", form: "prop", data: NSAppleEventDescriptor(typeCode: code("dpos")),
                                       container: item) else { return nil }
        let event = NSAppleEventDescriptor(eventClass: code("core"), eventID: code("setd"),
                                           targetDescriptor: NSAppleEventDescriptor(bundleIdentifier: "com.apple.finder"),
                                           returnID: AEReturnID(kAutoGenerateReturnID),
                                           transactionID: AETransactionID(kAnyTransactionID))
        event.setParam(property, forKeyword: AEKeyword(keyDirectObject))
        let point = NSAppleEventDescriptor.list()
        point.insert(NSAppleEventDescriptor(int32: Int32(x)), at: 1)
        point.insert(NSAppleEventDescriptor(int32: Int32(y)), at: 2)
        event.setParam(point, forKeyword: code("data"))
        return event
    }

    /// Déplace les icônes ; retourne les indices de celles que le Finder n'a pas pu placer par ce chemin.
    static func move(names: [String], xs: [Int], ys: [Int]) -> (moved: Int, failed: [Int]) {
        let lock = NSLock()
        var failed: [Int] = []
        var moved = 0
        let count = min(workers, names.count)
        DispatchQueue.concurrentPerform(iterations: count) { worker in
            var localMoved = 0
            var localFailed: [Int] = []
            for i in stride(from: worker, to: names.count, by: count) {
                if let e = event(name: names[i], x: xs[i], y: ys[i]),
                   let reply = try? e.sendEvent(options: [.waitForReply], timeout: 10),
                   reply.paramDescriptor(forKeyword: AEKeyword(keyErrorNumber)) == nil {
                    localMoved += 1
                } else {
                    localFailed.append(i)
                }
            }
            lock.lock(); moved += localMoved; failed += localFailed; lock.unlock()
        }
        return (moved, failed.sorted())
    }
}
