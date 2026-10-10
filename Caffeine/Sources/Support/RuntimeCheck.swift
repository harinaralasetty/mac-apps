import AppKit
import CaffeineCore

@MainActor
enum RuntimeCheck {
    enum Failure: Error { case check(String) }
    static func run() throws {
        let before = try AssertionSnapshot.read()
        // Capture existing caffeinate assertions, including assertions unrelated to us.
        let external = before.external(to: getpid()).filter { $0.name == "caffeinate command-line tool" }
        guard let resources = Bundle.main.resourceURL else { throw Failure.check("Bundle resources missing") }
        let awards = try AwardCatalog.read(from: resources.appendingPathComponent("Badges/catalog.json"))
        var uptime: TimeInterval = 100
        let session = AwakeSession(awards: awards, now: { uptime })
        let controller = AwakeController(backend: PowerAssertions(), session: session)
        defer { try? controller.turnOff() }
        func verify(_ condition: Bool, _ message: String) throws {
            guard condition else { throw Failure.check(message) }
            print("PASS: \(message)")
        }
        try verify(awards.count == 12, "all 12 awards packaged")
        for award in awards {
            let image = NSImage(contentsOf: resources.appendingPathComponent("Badges/\(award.image)"))
            try verify(image?.isValid == true, "badge image decodes: \(award.id)")
        }
        try verify(!controller.isActive, "startup in normal mode")
        try controller.set(.system, enabled: true)
        let system = try AssertionSnapshot.read().entries.filter { $0.pid == getpid() }
        try verify(system.contains { $0.keepsSystemAwake && $0.name == "Caffeine: system awake" }, "real system assertion acquired")
        try verify(!system.contains(where: \.keepsDisplayAwake), "system control leaves display independent")
        uptime += 300
        try controller.set(.display, enabled: true)
        try verify(session.elapsed == 300 && session.earnedIDs == ["first-sip"], "real assertion ownership advances session and unlocks First Sip")
        try verify(try AssertionSnapshot.read().entries.contains { $0.pid == getpid() && $0.keepsDisplayAwake }, "real display assertion acquired")
        try controller.set(.system, enabled: false)
        let displayOnly = try AssertionSnapshot.read().entries.filter { $0.pid == getpid() }
        try verify(!displayOnly.contains(where: \.keepsSystemAwake) && displayOnly.contains(where: \.keepsDisplayAwake), "display remains awake after system off")
        try verify(session.elapsed == 300, "mode switch preserves active session")
        session.systemWillSleep()
        uptime += 86400
        session.update(active: controller.isActive)
        try verify(session.elapsed == 0 && session.earnedIDs == ["first-sip"], "simulated system sleep excludes sleeping time")
        session.systemDidWake(active: controller.isActive)
        uptime += 10
        try verify(session.elapsed == 10, "wake with owned assertion starts a fresh session")
        try controller.turnOff()
        try verify(session.elapsed == 0, "all assertions off resets session")
        for _ in 0..<20 {
            try controller.set(.system, enabled: true)
            try controller.set(.display, enabled: true)
            try controller.turnOff()
        }
        let after = try AssertionSnapshot.read()
        try verify(!after.entries.contains { $0.pid == getpid() }, "20 repeated toggles release all owned assertions")
        for assertion in external {
            try verify(after.entries.contains(assertion), "external assertion retained: PID \(assertion.pid), ID \(assertion.id), \(assertion.type)")
        }
        print("PASS: external snapshot excludes current PID")
    }
}
