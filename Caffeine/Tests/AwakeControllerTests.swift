import Foundation
import Testing
@testable import CaffeineCore

@MainActor
private final class FakeBackend: AssertionBackend {
    var next: UInt32 = 100
    var owned: Set<UInt32> = []
    var released: [UInt32] = []
    var failCreate = false
    var failRelease: Set<UInt32> = []
    enum Failure: Error { case simulated }
    func create(_ mode: AwakeMode) throws -> UInt32 {
        if failCreate { throw Failure.simulated }
        next += 1; owned.insert(next); return next
    }
    func release(_ id: UInt32) throws {
        if failRelease.contains(id) { throw Failure.simulated }
        #expect(owned.contains(id))
        owned.remove(id); released.append(id)
    }
}

@MainActor @Test func controlsAreIndependentAndIdempotent() throws {
    let backend = FakeBackend()
    let controller = AwakeController(backend: backend)
    #expect(!controller.isActive)
    try controller.set(.display, enabled: true)
    try controller.set(.display, enabled: true)
    #expect(backend.owned.count == 1)
    #expect(!controller.isEnabled(.system))
    try controller.set(.system, enabled: true)
    try controller.set(.display, enabled: false)
    #expect(controller.isEnabled(.system))
    #expect(!controller.isEnabled(.display))
    try controller.turnOff()
    try controller.turnOff()
    #expect(!controller.isActive)
    #expect(backend.released == [101, 102])
}

@MainActor @Test func failedCreateDoesNotClaimAwake() throws {
    let backend = FakeBackend(); backend.failCreate = true
    let controller = AwakeController(backend: backend)
    #expect(throws: FakeBackend.Failure.self) { try controller.set(.system, enabled: true) }
    #expect(!controller.isActive)
}

@MainActor @Test func failedReleaseRetainsOwnershipAndStillReleasesOtherMode() throws {
    let backend = FakeBackend()
    let controller = AwakeController(backend: backend)
    try controller.set(.system, enabled: true)
    try controller.set(.display, enabled: true)
    backend.failRelease = [101]
    #expect(throws: FakeBackend.Failure.self) { try controller.turnOff() }
    #expect(controller.isEnabled(.system))
    #expect(!controller.isEnabled(.display))
    backend.failRelease = []
    try controller.turnOff()
    #expect(!controller.isActive)
    #expect(backend.owned.isEmpty)
}

@MainActor @Test func preferencesRestoreIndependentChoicesAndQuitPreservesThem() throws {
    let suite = "CaffeineTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let preferences = AwakePreferences(defaults: defaults)
    let first = AwakeController(backend: FakeBackend(), preferences: preferences)
    try first.set(.display, enabled: true)
    try first.turnOff(persist: false)
    #expect(!first.isActive)
    let second = AwakeController(backend: FakeBackend(), preferences: preferences)
    try second.restorePreferences()
    #expect(!second.isEnabled(.system))
    #expect(second.isEnabled(.display))
    try second.turnOff()
    let third = AwakeController(backend: FakeBackend(), preferences: preferences)
    try third.restorePreferences()
    #expect(!third.isActive)
}

@MainActor @Test func failedActionDoesNotSaveIncorrectPreference() throws {
    let suite = "CaffeineTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let preferences = AwakePreferences(defaults: defaults)
    let backend = FakeBackend(); backend.failCreate = true
    let controller = AwakeController(backend: backend, preferences: preferences)
    #expect(throws: FakeBackend.Failure.self) { try controller.set(.system, enabled: true) }
    #expect(!preferences.isEnabled(.system))
    preferences.set(.display, enabled: true)
    #expect(throws: FakeBackend.Failure.self) { try controller.restorePreferences() }
    #expect(preferences.isEnabled(.display))
}

@MainActor @Test func repeatedTogglesDoNotLeakOrReleaseForeignAssertions() throws {
    let backend = FakeBackend()
    let foreignID: UInt32 = 42
    backend.owned.insert(foreignID)
    let controller = AwakeController(backend: backend)
    for _ in 0..<50 {
        try controller.set(.system, enabled: true)
        try controller.set(.display, enabled: true)
        try controller.turnOff()
        #expect(backend.owned == [foreignID])
    }
    #expect(!backend.released.contains(foreignID))
}

// Catches session resets on mode switches, or failed operations claiming progress.
@MainActor @Test func sessionTracksActualOwnershipAcrossSwitchesAndFailures() throws {
    var seconds: TimeInterval = 100
    let awards = try AwardCatalog.read(from: URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Resources/Badges/catalog.json"))
    let session = AwakeSession(awards: awards, now: { seconds })
    let backend = FakeBackend()
    let controller = AwakeController(backend: backend, session: session)
    backend.failCreate = true
    #expect(throws: FakeBackend.Failure.self) { try controller.set(.system, enabled: true) }
    seconds += 400
    #expect(session.elapsed == 0)
    #expect(session.earnedIDs.isEmpty)
    backend.failCreate = false
    try controller.set(.system, enabled: true)
    seconds += 200
    try controller.set(.display, enabled: true)
    try controller.set(.system, enabled: false)
    #expect(session.elapsed == 200)
    seconds += 100
    backend.failRelease = Set(controller.assertions.values)
    #expect(throws: FakeBackend.Failure.self) { try controller.turnOff() }
    #expect(session.elapsed == 300)
    #expect(session.earnedIDs == ["first-sip"])
    backend.failRelease = []
    try controller.turnOff()
    #expect(session.elapsed == 0)
    seconds += 100
    try controller.set(.system, enabled: true)
    #expect(session.elapsed == 0)
    try controller.turnOff(persist: false)
    #expect(session.elapsed == 0)
}
