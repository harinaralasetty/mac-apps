import Foundation
import Testing
@testable import CaffeineCore

@MainActor private final class Clock {
    var time: TimeInterval = 10000
    var wall = Date(timeIntervalSince1970: 1700000000)
    func advance(_ seconds: TimeInterval) { time += seconds; wall += seconds }
    func assertion(_ id: UInt64, age: TimeInterval, type: String = "PreventUserIdleSystemSleep") -> SleepAssertion {
        SleepAssertion(pid: 42, id: UInt32(id), type: type, name: "caffeinate command-line tool", startedAt: wall.addingTimeInterval(-age), globalUniqueID: id)
    }
}
@MainActor private struct Backend: AssertionBackend {
    func create(_ mode: AwakeMode) throws -> UInt32 { 100 }
    func release(_ id: UInt32) throws {}
}
@MainActor @Test func preexistingCLITimeCreditsAwardsOnceAtExactBoundaries() throws {
    let clock = Clock()
    let awards = try AwardCatalog.read(from: URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Resources/Badges/catalog.json"))
    let session = AwakeSession(awards: awards, now: { clock.time })
    let cli = CLIActivityClock(now: { clock.time }, wallNow: { clock.wall })
    let controller = AwakeController(backend: Backend(), session: session, cliClock: cli)
    let existing = clock.assertion(1, age: 299)
    controller.observeExternalAssertions([existing])
    #expect(cli.elapsed == 299 && session.elapsed == 299 && session.earnedIDs.isEmpty)
    clock.advance(1)
    controller.observeExternalAssertions([existing])
    #expect(cli.elapsed == 300 && session.elapsed == 300 && session.earnedIDs == ["first-sip"])
    for _ in 0..<10 { controller.observeExternalAssertions([existing]) }
    #expect(session.elapsed == 300 && session.earnedIDs == ["first-sip"])
    let relaunched = CLIActivityClock(now: { clock.time }, wallNow: { clock.wall })
    relaunched.observe([existing])
    #expect(relaunched.elapsed == 300)
}
@MainActor @Test func overlappingCLIIdentityContinuesButRestartedPIDResetsUnprovenStreak() throws {
    let clock = Clock()
    let session = AwakeSession(awards: [], now: { clock.time })
    let cli = CLIActivityClock(now: { clock.time }, wallNow: { clock.wall })
    let controller = AwakeController(backend: Backend(), session: session, cliClock: cli)
    let a = clock.assertion(1, age: 7200), b = clock.assertion(2, age: 3600)
    controller.observeExternalAssertions([a, b])
    clock.advance(10); controller.observeExternalAssertions([b])
    #expect(cli.elapsed == 7210 && session.elapsed == 7210)
    clock.advance(20)
    controller.observeExternalAssertions([clock.assertion(3, age: 5)])
    #expect(cli.elapsed == 5 && session.elapsed == 5)
    controller.observeExternalAssertions([])
    #expect(cli.elapsed == nil)
}
@MainActor @Test func missingFutureMetadataACAndCalendarChangesStayConservative() {
    let clock = Clock()
    let cli = CLIActivityClock(now: { clock.time }, wallNow: { clock.wall })
    cli.observe([SleepAssertion(pid: 42, id: 1, type: "PreventUserIdleSystemSleep", name: "caffeinate command-line tool")])
    #expect(cli.elapsed == nil)
    let future = clock.assertion(1, age: -100)
    cli.observe([future]); #expect(cli.elapsed == 0)
    clock.advance(10); cli.observe([future]); #expect(cli.elapsed == 10)
    cli.observe([])
    let acOnly = clock.assertion(2, age: 7200, type: "PreventSystemSleep")
    cli.observe([acOnly]); #expect(cli.elapsed == 0)
    clock.advance(10); cli.observe([acOnly]); #expect(cli.elapsed == 10)
    clock.wall += 86400
    clock.time += 10
    cli.observe([acOnly]); #expect(cli.elapsed == 20)
    cli.observe([clock.assertion(3, age: 7200)]); #expect(cli.elapsed == 0)
}

@MainActor @Test func CLIClaimPersistenceRestoresOverlapWithoutAddingIntervals() throws {
    let suite = "CaffeineCLIClaimsTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let clock = Clock()
    let awards = try AwardCatalog.read(from: URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Resources/Badges/catalog.json"))
    let session = AwakeSession(awards: awards, defaults: defaults, now: { clock.time })
    let cli = CLIActivityClock(defaults: defaults, now: { clock.time }, wallNow: { clock.wall })
    let controller = AwakeController(backend: Backend(), session: session, cliClock: cli)
    let a = clock.assertion(10, age: 14400), b = clock.assertion(11, age: 3600)
    controller.observeExternalAssertions([a, b])
    #expect(session.elapsed == 14400 && session.earnedIDs.count == 3)
    clock.advance(10); controller.observeExternalAssertions([b])
    #expect(session.elapsed == 14410)
    #expect(defaults.data(forKey: "awards.cliIntervals.v1") != nil)
    for _ in 0..<3 {
        let reopened = AwakeSession(awards: awards, defaults: defaults, now: { clock.time })
        let restored = CLIActivityClock(defaults: defaults, now: { clock.time }, wallNow: { clock.wall })
        let next = AwakeController(backend: Backend(), session: reopened, cliClock: restored)
        next.observeExternalAssertions([b])
        #expect(reopened.elapsed == 14410 && reopened.earnedIDs.count == 3)
        next.observeExternalAssertions([b])
        #expect(reopened.elapsed == 14410 && reopened.earnedIDs.count == 3)
        next.observeExternalAssertions([clock.assertion(12, age: 1)])
        #expect(reopened.elapsed == 1 && reopened.earnedIDs.count == 3)
    }
    // A reused global ID with a different start must not restore old claims.
    let fresh = CLIActivityClock(defaults: defaults, now: { clock.time }, wallNow: { clock.wall })
    fresh.observe([clock.assertion(10, age: 5)])
    #expect(fresh.elapsed == 5)
}

@MainActor @Test func continuingCLIHistoryIncludesAcceptedSleepButAppOnlyResets() throws {
    let clock = Clock()
    let session = AwakeSession(awards: [], now: { clock.time })
    let cli = CLIActivityClock(now: { clock.time }, wallNow: { clock.wall })
    let controller = AwakeController(backend: Backend(), session: session, cliClock: cli)
    let existing = clock.assertion(1, age: 3600)
    controller.observeExternalAssertions([existing])
    session.systemWillSleep()
    clock.advance(86400)
    controller.observeExternalAssertions([existing])
    #expect(session.elapsed == 0)
    session.systemDidWake(active: true)
    controller.observeExternalAssertions([existing])
    #expect(session.elapsed == 90000)
    controller.observeExternalAssertions([])
    try controller.set(.system, enabled: true)
    session.systemWillSleep(); clock.advance(3600)
    session.systemDidWake(active: true)
    #expect(session.elapsed == 0)
}
