import Foundation
import Darwin
import Testing
@testable import CaffeinateUICore

@MainActor private final class OwnedBackend: AssertionBackend {
    var released: [UInt32] = []
    func create(_ mode: AwakeMode) throws -> UInt32 { mode == .system ? 10 : 11 }
    func release(_ id: UInt32) throws { released.append(id) }
}
@MainActor private final class Processes: CLIProcessAccess {
    var entries: [SleepAssertion] = []
    var identities: [Int32: CLIProcessIdentity] = [:]
    var signaled: [Int32] = []
    var failTermination = false
    var changeIdentity = false
    func inspect(_ pid: Int32) throws -> CLIProcessIdentity? { identities[pid] }
    func terminate(_ expected: CLIProcessIdentity) throws {
        if changeIdentity { identities[expected.pid] = identity(expected.pid, start: 99) }
        guard identities[expected.pid] == expected, !failTermination else {
            throw CLIStopError(issues: ["termination rejected"])
        }
        signaled.append(expected.pid)
        identities[expected.pid] = nil
        entries.removeAll { $0.pid == expected.pid }
    }
    func snapshot() -> AssertionSnapshot { AssertionSnapshot(entries: entries, onACPower: true) }
    func stopper() -> StandaloneCLIStopper { StandaloneCLIStopper(processes: self, userID: 501, read: { self.snapshot() }) }
    func add(_ pid: Int32, words: [String] = ["/usr/bin/caffeinate", "-i"], parent: Bool = true, children: Bool = false) {
        identities[pid] = identity(pid, words: words, parent: parent, children: children)
        entries.append(SleepAssertion(pid: pid, id: UInt32(pid), type: "PreventUserIdleSystemSleep", name: "caffeinate command-line tool", globalUniqueID: UInt64(pid)))
    }
}
private func identity(_ pid: Int32, words: [String] = ["/usr/bin/caffeinate", "-i"],
                      parent: Bool = true, children: Bool = false, start: UInt64 = 1) -> CLIProcessIdentity {
    CLIProcessIdentity(pid: pid, uid: 501, parentPID: 1, startSeconds: start, startMicroseconds: 0,
                       executable: "/usr/bin/caffeinate", argumentWords: words, hasChildren: children, shellOrDetached: parent)
}

@Test func unifiedMenuControlsMatchSteamForEveryOwnershipState() {
    for (app, cli) in [(false, false), (true, false), (false, true), (true, true)] {
        let state = AwakeMenuState(appActive: app, cliActive: cli)
        #expect(state.canTurnOff == (app || cli))
        #expect(state.canTurnOn == !(app || cli))
        #expect(state.steaming == state.canTurnOff)
        #expect(state.title.hasPrefix(app || cli ? "Caffeinate UI: On" : "Caffeinate UI: Off"))
    }
    let unrelated = AwakeMenuState(appActive: false, cliActive: false, otherActive: true)
    #expect(!unrelated.steaming && !unrelated.canTurnOff && unrelated.canTurnOn)
}

@MainActor @Test func unifiedOffAppCLIAndMixedResetTimerPreserveAwardsAndOtherApps() async throws {
    let awards = try AwardCatalog.read(from: URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Resources/Badges/catalog.json"))
    for (app, cli) in [(true, false), (false, true), (true, true), (false, false)] {
        var time: TimeInterval = 0
        let suite = "CaffeinateUIUnifiedOff.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let session = AwakeSession(awards: awards, defaults: defaults, now: { time })
        let backend = OwnedBackend(), processes = Processes()
        let controller = AwakeController(backend: backend, session: session)
        if cli { processes.add(77); processes.add(78) }
        let other = SleepAssertion(pid: 80, id: 80, type: "PreventUserIdleDisplaySleep", name: "Other application")
        processes.entries.append(other)
        controller.observeExternalAssertions(processes.entries)
        if app { try controller.set(.system, enabled: true); try controller.set(.display, enabled: true) }
        time = 300
        controller.observeExternalAssertions(processes.entries)
        let earned = session.earnedIDs
        #expect(earned == (app || cli ? ["first-sip"] : []))
        try await controller.turnOffAll(using: processes.stopper())
        #expect(!controller.isSessionActive && session.elapsed == 0)
        #expect(session.earnedIDs == earned)
        #expect(processes.entries == [other])
        #expect(processes.signaled == (cli ? [77, 78] : []))
        #expect(backend.released.count == (app ? 2 : 0))
        let reopened = AwakeSession(awards: awards, defaults: defaults)
        #expect(reopened.earnedIDs == earned && reopened.elapsed == 0)
        try await controller.turnOffAll(using: processes.stopper())
        #expect(processes.signaled == (cli ? [77, 78] : []))
    }
}

@MainActor @Test func unifiedOffDoesNotPretendSuccessWhenTerminationFailsOrIdentityChanges() async throws {
    for changed in [false, true] {
        let processes = Processes(), backend = OwnedBackend()
        processes.add(77)
        processes.failTermination = !changed
        processes.changeIdentity = changed
        let controller = AwakeController(backend: backend, session: AwakeSession(awards: []))
        try controller.set(.system, enabled: true)
        do { try await controller.turnOffAll(using: processes.stopper()); Issue.record("Off must report a failed or stale target") }
        catch { #expect(error is CLIStopError) }
        #expect(processes.signaled.isEmpty && !controller.isActive && controller.isSessionActive)
        let state = AwakeMenuState(appActive: controller.isActive, cliActive: !controller.externalCaffeinate.isEmpty)
        #expect(state.steaming && state.canTurnOff && !state.canTurnOn)
    }
}

@MainActor @Test func unifiedOffProtectsWrappedWatchedChildAndApplicationOwnedSessions() async throws {
    let processes = Processes()
    processes.add(77, words: ["/usr/bin/caffeinate", "-i", "/bin/sleep", "100"])
    processes.add(78, words: ["/usr/bin/caffeinate", "-i", "-w", "500"])
    processes.add(79, children: true)
    processes.add(80, parent: false)
    let controller = AwakeController(backend: OwnedBackend())
    do { try await controller.turnOffAll(using: processes.stopper()); Issue.record("Protected workloads must be reported") }
    catch {
        let error = try #require(error as? CLIStopError)
        #expect(error.issues.count == 4)
    }
    #expect(processes.signaled.isEmpty && processes.entries.count == 4 && controller.isSessionActive)
    #expect(identity(77).protectedReason(userID: 502) != nil)
    #expect(CLIProcessIdentity.hasStandaloneArguments(["caffeinate", "-is", "-t20"]))
    #expect(CLIProcessIdentity.hasStandaloneArguments(["/usr/bin/caffeinate"]))
    #expect(!CLIProcessIdentity.hasStandaloneArguments(["caffeinate", "-t", "20", "echo", "hello"]))
}

@MainActor @Test func unifiedOffHandlesAlreadyExitedCLIWithoutSignalingReusedPID() async throws {
    let processes = Processes()
    processes.add(77)
    let controller = AwakeController(backend: OwnedBackend(), session: AwakeSession(awards: []))
    controller.observeExternalAssertions(processes.entries)
    processes.entries = []; processes.identities = [:]
    try await controller.turnOffAll(using: processes.stopper())
    #expect(processes.signaled.isEmpty && !controller.isSessionActive && controller.session?.elapsed == 0)
}

// The snapshot supplied to Off includes only this test-owned PID. Existing user
// CLI and other applications are never candidates. No display assertion/launch.
@MainActor @Test func unifiedOffTerminatesOnlyOwnedStandaloneLiveFixture() async throws {
    let launcher = Process(), pipe = Pipe()
    launcher.executableURL = URL(fileURLWithPath: "/bin/zsh")
    launcher.arguments = ["-c", "/usr/bin/caffeinate -i -t 20 </dev/null >/dev/null 2>&1 & echo $!"]
    launcher.standardOutput = pipe
    try launcher.run()
    let output = pipe.fileHandleForReading.readDataToEndOfFile()
    launcher.waitUntilExit()
    let pid = try #require(Int32(String(decoding: output, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)))
    try await Task.sleep(for: .milliseconds(200))
    let unverified = try #require(try MacCLIProcessAccess().inspect(pid))
    #expect(unverified.protectedReason(userID: getuid()) != nil)
    let access = MacCLIProcessAccess(authorizedDetached: [unverified.birth])
    let initial = try #require(try access.inspect(pid))
    defer {
        if let current = try? access.inspect(pid), current == initial { try? access.terminate(current) }
    }
    #expect(initial.protectedReason(userID: getuid()) == nil)
    let foreign = try AssertionSnapshot.read().entries.filter { $0.pid != pid && $0.pid != getpid() }
    let stopper = StandaloneCLIStopper(processes: access, read: {
        let snapshot = try AssertionSnapshot.read()
        return AssertionSnapshot(entries: snapshot.entries.filter { $0.pid == pid }, onACPower: snapshot.onACPower)
    })
    let fixtureAssertions = try stopper.snapshot().entries
    #expect(!fixtureAssertions.isEmpty)
    let controller = AwakeController(backend: PowerAssertions(), session: AwakeSession(awards: []))
    try controller.set(.system, enabled: true)
    try await controller.turnOffAll(using: stopper)
    #expect(!controller.isSessionActive && controller.session?.elapsed == 0)
    let after = try AssertionSnapshot.read().entries
    #expect(!after.contains { $0.pid == pid || $0.pid == getpid() })
    for entry in foreign { #expect(after.contains(entry)) }
}
