import AppKit
import CaffeinateUICore

@MainActor
enum RuntimeCheck {
    enum Failure: Error { case check(String) }
    static func awardsWindowCheck(outputDirectory: URL) throws {
        func trace(_ message: String) {
            FileHandle.standardError.write(Data("Awards UI diagnostic: \(message)\n".utf8))
        }
        NSSetUncaughtExceptionHandler { exception in
            let message = "Awards UI exception: \(exception.name.rawValue): \(exception.reason ?? "no reason")\n" + exception.callStackSymbols.prefix(20).joined(separator: "\n") + "\n"
            FileHandle.standardError.write(Data(message.utf8))
        }
        trace("initializing AppKit")
        _ = NSApplication.shared
        trace("reading badge catalog")
        guard let resources = Bundle.main.resourceURL else { throw Failure.check("Bundle resources missing") }
        let awards = try AwardCatalog.read(from: resources.appendingPathComponent("Badges/catalog.json"))
        trace("creating Awards controller")
        let controller = AwardsWindowController(awards: awards)
        var seconds: TimeInterval = 0
        let session = AwakeSession(awards: awards, now: { seconds })
        session.update(active: true)
        seconds = 299
        session.update(active: true)
        controller.presentation.update(from: session)
        trace("creating native Awards window")
        let first = controller.show(activate: false)
        trace("checking repeated open")
        guard first === controller.show(activate: false), first.title == "Caffeinate UI Awards" else {
            throw Failure.check("Awards window must be reused")
        }
        first.close()
        trace("checking Close/reopen")
        guard first === controller.show(activate: false) else { throw Failure.check("Close/reopen created another window") }
        print("PASS: repeated opens and Close/reopen reuse one native Awards window")
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        for (name, size) in [("awards-compact", NSSize(width: 400, height: 460)), ("awards-window", NSSize(width: 600, height: 640))] {
            trace("laying out \(name)")
            first.setContentSize(size)
            guard let view = first.contentView else { throw Failure.check("Awards content missing") }
            view.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.2))
            trace("allocating bitmap for \(name)")
            guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { throw Failure.check("Awards render unavailable") }
            view.cacheDisplay(in: view.bounds, to: bitmap)
            trace("encoding \(name)")
            guard let png = bitmap.representation(using: .png, properties: [:]) else { throw Failure.check("Awards PNG unavailable") }
            try png.write(to: outputDirectory.appendingPathComponent(name + ".png"))
            print("PASS: Awards native content rendered at \(Int(size.width)) × \(Int(size.height))")
        }
        seconds = 300
        session.update(active: true)
        controller.presentation.update(from: session)
        guard controller.presentation.earnedIDs == ["first-sip"] else { throw Failure.check("Awards presentation missed unlock") }
        print("PASS: presentation changes from locked to earned at the exact threshold, without user defaults")
        first.setContentSize(NSSize(width: 600, height: 640))
        if let view = first.contentView {
            view.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.2))
            guard let bitmap = view.bitmapImageRepForCachingDisplay(in: view.bounds) else { throw Failure.check("Earned Awards render unavailable") }
            view.cacheDisplay(in: view.bounds, to: bitmap)
            guard let png = bitmap.representation(using: .png, properties: [:]) else { throw Failure.check("Earned Awards PNG unavailable") }
            try png.write(to: outputDirectory.appendingPathComponent("awards-earned.png"))
            print("PASS: earned full-colour and locked grayscale states rendered without user defaults")
        }
        first.close()
    }
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
        try verify(StatusBarController.statusTitle(appActive: false, cliActive: false) == "Caffeinate UI: Off", "app-only Off status")
        try verify(StatusBarController.statusTitle(appActive: true, cliActive: false) == "Caffeinate UI: On", "app-only On status")
        try verify(StatusBarController.statusTitle(appActive: false, cliActive: true) == "Caffeinate UI: Off — CLI caffeinate active", "CLI steam explicitly identifies app Off")
        try verify(StatusBarController.statusTitle(appActive: true, cliActive: true) == "Caffeinate UI: On — CLI caffeinate active", "mixed app and CLI status")
        for award in awards {
            let image = NSImage(contentsOf: resources.appendingPathComponent("Badges/\(award.image)"))
            try verify(image?.isValid == true, "badge image decodes: \(award.id)")
        }
        try verify(!controller.isActive, "startup in normal mode")
        try controller.set(.system, enabled: true)
        let system = try AssertionSnapshot.read().entries.filter { $0.pid == getpid() }
        try verify(system.contains { $0.keepsSystemAwake && $0.name == "Caffeinate UI: system awake" }, "real system assertion acquired")
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
        controller.observeExternalAssertions(external, onACPower: before.onACPower)
        let cliActive = !controller.externalCaffeinate.isEmpty
        try controller.set(.system, enabled: true)
        try controller.turnOff()
        try verify(!controller.isActive && controller.isSessionActive == cliActive,
                   "Turn Off releases app assertion immediately; steam retains only qualifying CLI activity")
        controller.observeExternalAssertions([])
        try verify(!controller.isSessionActive, "steam clears when isolated CLI snapshot ends")
        for assertion in external {
            try verify(after.entries.contains(assertion), "external assertion retained: PID \(assertion.pid), ID \(assertion.id), \(assertion.type)")
        }
        print("PASS: external snapshot excludes current PID")
    }
}
