import Foundation
import Testing
@testable import CaffeinateUICore

@MainActor private final class SessionClock { var seconds: TimeInterval = 100 }
private let badgeDirectory = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent().appendingPathComponent("Resources/Badges")
private func readAwards() throws -> [CaffeinateUIAward] {
    try AwardCatalog.read(from: badgeDirectory.appendingPathComponent("catalog.json"))
}

// Catches off time or another process incorrectly earning CaffeinateUI awards.
@MainActor @Test func inactiveTimeDoesNotCount() throws {
    let clock = SessionClock()
    let session = AwakeSession(awards: try readAwards(), now: { clock.seconds })
    session.update(active: false)
    clock.seconds += 86400
    session.update(active: false)
    #expect(session.elapsed == 0)
    #expect(session.earnedIDs.isEmpty)
    session.update(active: true)
    clock.seconds += 299
    session.update(active: true)
    #expect(session.elapsed == 299)
    #expect(session.earnedIDs.isEmpty)
    clock.seconds += 1
    session.update(active: true)
    #expect(session.earnedIDs == ["first-sip"])
}

// Catches an early unlock, a missed boundary, or final award ordering drift.
@MainActor @Test func milestonesUnlockAtExactBoundaries() throws {
    let clock = SessionClock()
    let session = AwakeSession(awards: try readAwards(), now: { clock.seconds })
    session.update(active: true)
    let thresholds: [TimeInterval] = [300, 3600, 14400, 28800, 86400, 259200, 604800, 1209600, 2592000, 5184000, 7776000, 31536000]
    #expect(session.awards.first { $0.id == "legally-an-espresso-machine" }?.title == "Head Barista")
    #expect(session.awards.first { $0.id == "your-mac-is-legally-a-cafe" }?.title == "Your Mac Is Legally a Café")
    let ids = ["first-sip", "espresso-yourself", "just-one-more-cup", "the-daily-grind", "certified-all-nighter", "decaf-is-a-myth", "sleep-is-a-rumor", "bean-there-done-that", "your-mac-is-legally-a-cafe", "roast-level-critical", "legally-an-espresso-machine", "caffeine-overdose"]
    for index in thresholds.indices {
        clock.seconds = 100 + thresholds[index] - 1
        session.update(active: true)
        #expect(!session.earnedIDs.contains(ids[index]))
        clock.seconds += 1
        session.update(active: true)
        #expect(session.earnedIDs == Set(ids.prefix(index + 1)))
    }
}

// Catches skipped awards when a timer tick is delayed; unlock before resetting.
@MainActor @Test func turningOffCapturesFinalAwardsAndResetsElapsed() throws {
    let clock = SessionClock()
    let session = AwakeSession(awards: try readAwards(), now: { clock.seconds })
    session.update(active: true)
    clock.seconds += 14400
    session.update(active: false)
    #expect(session.elapsed == 0)
    #expect(session.earnedIDs == ["first-sip", "espresso-yourself", "just-one-more-cup"])
    session.update(active: true)
    clock.seconds += 10
    #expect(session.elapsed == 10)
}

// Catches earned badge loss or accidentally restoring a previous streak.
@MainActor @Test func relaunchRestoresAwardsButNeverElapsed() throws {
    let suite = "Caffeinate UIAwardsTests.\(UUID().uuidString)"
    let defaults = UserDefaults(suiteName: suite)!
    defer { defaults.removePersistentDomain(forName: suite) }
    let clock = SessionClock()
    let first = AwakeSession(awards: try readAwards(), defaults: defaults, now: { clock.seconds })
    first.update(active: true)
    clock.seconds += 3600
    first.update(active: true)
    let next = AwakeSession(awards: try readAwards(), defaults: defaults, now: { clock.seconds })
    #expect(next.earnedIDs == ["first-sip", "espresso-yourself"])
    #expect(next.elapsed == 0)
    next.update(active: true)
    clock.seconds += 5
    #expect(next.elapsed == 5)
}

// Catches asleep time earning awards or a periodic refresh restarting too early.
@MainActor @Test func sleepEndsStreakAndWakeBeginsFreshOnlyWhenActive() throws {
    let clock = SessionClock()
    let session = AwakeSession(awards: try readAwards(), now: { clock.seconds })
    session.update(active: true)
    clock.seconds += 300
    session.systemWillSleep()
    #expect(session.earnedIDs == ["first-sip"])
    clock.seconds += 86400
    session.update(active: true)
    #expect(session.elapsed == 0)
    #expect(session.earnedIDs == ["first-sip"])
    session.systemDidWake(active: true)
    clock.seconds += 20
    #expect(session.elapsed == 20)
    session.systemWillSleep()
    session.systemDidWake(active: false)
    clock.seconds += 3600
    #expect(session.elapsed == 0)
}

@MainActor @Test func streakDurationLabelsRemainReadableBeyondADay() throws {
    let clock = SessionClock()
    let session = AwakeSession(awards: try readAwards(), now: { clock.seconds })
    session.update(active: true)
    #expect(session.durationLabel == "00:00:00")
    clock.seconds += 3661
    #expect(session.durationLabel == "01:01:01")
    clock.seconds += 86400
    #expect(session.durationLabel == "1d 01:01:01")
}

// Catches malformed or duplicate catalog entries silently breaking unlocks.
@Test func invalidAwardCatalogIsRejected() throws {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".json")
    defer { try? FileManager.default.removeItem(at: url) }
    try Data(#"{"schema_version":1,"awards":[{"id":"bad","title":"Bad","threshold_seconds":0,"threshold_label":"zero","image":"bad.png"}]}"#.utf8).write(to: url)
    #expect(throws: (any Error).self) { try AwardCatalog.read(from: url) }
}
