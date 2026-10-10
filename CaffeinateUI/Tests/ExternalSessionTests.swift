import Foundation
import Testing
@testable import CaffeinateUICore

@MainActor private struct TestBackend: AssertionBackend {
    func create(_ mode: AwakeMode) throws -> UInt32 { mode == .system ? 1 : 2 }
    func release(_ id: UInt32) throws {}
}
private func cli(_ pid: Int32 = 100, type: String = "PreventUserIdleSystemSleep", name: String = "caffeinate command-line tool") -> SleepAssertion {
    SleepAssertion(pid: pid, id: UInt32(pid), type: type, name: name)
}
@MainActor @Test func steamTracksAppAndCLIIndependentlyAcrossOffAndReopen() throws {
    let controller = AwakeController(backend: TestBackend())
    #expect(!controller.isSessionActive)
    try controller.set(.system, enabled: true)
    #expect(controller.isActive && controller.isSessionActive && !controller.isEnabled(.display))
    try controller.turnOff()
    #expect(!controller.isActive && !controller.isSessionActive)
    controller.observeExternalAssertions([cli()])
    #expect(!controller.isActive && controller.isSessionActive)
    try controller.set(.system, enabled: true)
    try controller.turnOff()
    #expect(!controller.isActive && controller.isSessionActive && !controller.isEnabled(.display))
    let reopened = AwakeController(backend: TestBackend())
    reopened.observeExternalAssertions([cli()])
    #expect(!reopened.isActive && reopened.isSessionActive)
    controller.observeExternalAssertions([])
    reopened.observeExternalAssertions([])
    #expect(!controller.isSessionActive && !reopened.isSessionActive)
}
@MainActor @Test func qualifyingCLIContinuesAcrossOwnersAndNeverCountsUnrelatedApps() throws {
    var time: TimeInterval = 0
    let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Resources/Badges/catalog.json")
    let session = AwakeSession(awards: try AwardCatalog.read(from: url), now: { time })
    let controller = AwakeController(backend: TestBackend(), session: session)
    controller.observeExternalAssertions([cli(name: "Other application"), cli(type: "UserIsActive")])
    time = 1000
    #expect(session.elapsed == 0 && session.earnedIDs.isEmpty)
    controller.observeExternalAssertions([cli()])
    time += 299
    controller.observeExternalAssertions([cli(), cli(101, type: "PreventUserIdleDisplaySleep")])
    #expect(session.elapsed == 299 && session.earnedIDs.isEmpty)
    try controller.set(.system, enabled: true)
    time += 1
    controller.observeExternalAssertions([cli(101, type: "PreventUserIdleDisplaySleep")])
    #expect(session.elapsed == 300 && session.earnedIDs == ["first-sip"])
    try controller.turnOff()
    #expect(session.elapsed == 300)
    time += 1
    controller.observeExternalAssertions([])
    #expect(session.elapsed == 0 && session.earnedIDs == ["first-sip"])
    controller.observeExternalAssertions([cli(102, type: "PreventSystemSleep")])
    #expect(session.elapsed == 0)
    time += 10
    controller.observeExternalAssertions([cli(102, type: "PreventSystemSleep")])
    #expect(session.elapsed == 10 && session.earnedIDs.count == 1)
    controller.observeExternalAssertions([cli(102, type: "PreventSystemSleep")], onACPower: false)
    #expect(!controller.isSessionActive && session.elapsed == 0)
}

@MainActor @Test func missingCLISnapshotDoesNotUnlockAtUnobservedBoundary() throws {
    var time: TimeInterval = 0
    let url = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Resources/Badges/catalog.json")
    let session = AwakeSession(awards: try AwardCatalog.read(from: url), now: { time })
    let controller = AwakeController(backend: TestBackend(), session: session)
    controller.observeExternalAssertions([cli()])
    time = 299
    controller.observeExternalAssertions([cli()])
    time = 301
    controller.observeExternalAssertions([])
    #expect(session.elapsed == 0 && session.earnedIDs.isEmpty)
}

// Safe while the user's display is asleep: never request -d, -u or display mode.
@MainActor @Test func realSystemOnlyCLIAppOffAndExpiry() async throws {
    let child = Process()
    child.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
    child.arguments = ["-i", "-t", "3"]
    let controller = AwakeController(backend: PowerAssertions(), session: AwakeSession(awards: []))
    defer {
        try? controller.turnOff()
        if child.isRunning { child.terminate(); child.waitUntilExit() }
    }
    func owned() throws -> [SleepAssertion] {
        try AssertionSnapshot.read().entries.filter { $0.pid == getpid() }
    }
    func cliEntries() throws -> [SleepAssertion] {
        try AssertionSnapshot.read().entries.filter { $0.pid == child.processIdentifier }
    }
    try controller.set(.system, enabled: true)
    #expect(controller.isSessionActive && controller.isActive)
    let appOnly = try owned()
    #expect(appOnly.contains { $0.keepsSystemAwake })
    #expect(!appOnly.contains { $0.keepsDisplayAwake })
    try controller.turnOff()
    #expect(!controller.isSessionActive && !controller.isActive)
    let appOff = try owned()
    #expect(appOff.isEmpty)
    try child.run()
    try await Task.sleep(for: .milliseconds(200))
    let external = try cliEntries()
    #expect(external.contains { $0.keepsSystemAwake })
    #expect(!external.contains { $0.keepsDisplayAwake })
    controller.observeExternalAssertions(external)
    #expect(controller.isSessionActive && !controller.isActive)
    try controller.set(.system, enabled: true)
    try controller.turnOff()
    #expect(controller.isSessionActive && !controller.isActive)
    let mixedOff = try owned(), cliStillActive = try cliEntries()
    #expect(mixedOff.isEmpty)
    #expect(cliStillActive == external)
    let reopened = AwakeController(backend: TestBackend())
    reopened.observeExternalAssertions(external)
    #expect(reopened.isSessionActive && !reopened.isActive)
    try await Task.sleep(for: .milliseconds(3100))
    let ended = try cliEntries()
    #expect(!child.isRunning && ended.isEmpty)
    controller.observeExternalAssertions(ended)
    reopened.observeExternalAssertions(ended)
    #expect(!controller.isSessionActive && !reopened.isSessionActive)
    #expect(controller.session?.elapsed == 0)
}

// Every process here is created, tracked and cleaned up by this test. No user
// preferences or earned awards are read or written. Never signal existing PIDs.
@MainActor @Test func realCLIFlagsExpiryAndMultipleProcesses() async throws {
    var children: [Process] = []
    defer { for child in children where child.isRunning { child.terminate(); child.waitUntilExit() } }
    func start(_ args: [String]) throws -> Process {
        let child = Process()
        child.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
        child.arguments = args
        try child.run()
        children.append(child)
        return child
    }
    func snapshot(_ processes: [Process]) throws -> [SleepAssertion] {
        let pids = Set(processes.map(\.processIdentifier))
        return try AssertionSnapshot.read().entries.filter { pids.contains($0.pid) }
    }
    let system = try start(["-i", "-t", "8"])
    let display = try start(["-d", "-t", "2"])
    try await Task.sleep(for: .milliseconds(400))
    let session = AwakeSession(awards: [])
    let controller = AwakeController(backend: TestBackend(), session: session)
    let both = try snapshot([system, display])
    #expect(both.contains { $0.pid == system.processIdentifier && $0.keepsSystemAwake })
    #expect(both.contains { $0.pid == display.processIdentifier && $0.keepsDisplayAwake })
    controller.observeExternalAssertions(both)
    try await Task.sleep(for: .seconds(1))
    controller.observeExternalAssertions(try snapshot([system, display]))
    #expect(session.elapsed >= 1)
    let before = session.elapsed
    try await Task.sleep(for: .milliseconds(1400))
    controller.observeExternalAssertions(try snapshot([system, display]))
    #expect(!display.isRunning)
    #expect(controller.isSessionActive && session.elapsed > before)
    system.terminate(); system.waitUntilExit()
    controller.observeExternalAssertions(try snapshot([system, display]))
    #expect(!controller.isSessionActive && session.elapsed == 0)
    let userActive = try start(["-u", "-t", "1"])
    try await Task.sleep(for: .milliseconds(300))
    controller.observeExternalAssertions(try snapshot([userActive]))
    #expect(!controller.isSessionActive && session.elapsed == 0)
    let diskOnly = try start(["-m", "-t", "1"])
    try await Task.sleep(for: .milliseconds(300))
    controller.observeExternalAssertions(try snapshot([diskOnly]))
    #expect(!controller.isSessionActive && session.elapsed == 0)
    let defaultMode = try start(["-t", "1"])
    try await Task.sleep(for: .milliseconds(300))
    controller.observeExternalAssertions(try snapshot([defaultMode]))
    #expect(controller.isSessionActive)
    try await Task.sleep(for: .seconds(1))
    controller.observeExternalAssertions(try snapshot([defaultMode]))
    #expect(!controller.isSessionActive && session.elapsed == 0)
    let watched = Process()
    watched.executableURL = URL(fileURLWithPath: "/bin/sleep")
    watched.arguments = ["2"]
    try watched.run(); children.append(watched)
    let waitMode = try start(["-i", "-w", String(watched.processIdentifier)])
    try await Task.sleep(for: .milliseconds(400))
    controller.observeExternalAssertions(try snapshot([waitMode]))
    #expect(controller.isSessionActive)
    try await Task.sleep(for: .seconds(2))
    controller.observeExternalAssertions(try snapshot([waitMode]))
    #expect(!controller.isSessionActive && session.elapsed == 0)
}
