import Foundation

public struct CaffeineAward: Decodable, Equatable, Sendable {
    public let id: String
    public let title: String
    public let thresholdSeconds: TimeInterval
    public let thresholdLabel: String
    public let image: String
    enum CodingKeys: String, CodingKey {
        case id, title, image
        case thresholdSeconds = "threshold_seconds"
        case thresholdLabel = "threshold_label"
    }
}

/// The bundled catalog is the single source for names, milestones and artwork.
public enum AwardCatalog {
    private struct Catalog: Decodable {
        let schemaVersion: Int
        let awards: [CaffeineAward]
        enum CodingKeys: String, CodingKey { case schemaVersion = "schema_version", awards }
    }
    public enum Failure: Error { case invalidCatalog }
    public static func read(from url: URL) throws -> [CaffeineAward] {
        let catalog = try JSONDecoder().decode(Catalog.self, from: Data(contentsOf: url))
        guard catalog.schemaVersion == 1, !catalog.awards.isEmpty else { throw Failure.invalidCatalog }
        var ids: Set<String> = []
        var previous: TimeInterval = 0
        for award in catalog.awards {
            guard !award.id.isEmpty,
                  award.id.unicodeScalars.allSatisfy({ (97...122).contains($0.value) || (48...57).contains($0.value) || $0.value == 45 }),
                  ids.insert(award.id).inserted,
                  !award.title.isEmpty, !award.thresholdLabel.isEmpty,
                  award.thresholdSeconds.isFinite, award.thresholdSeconds > previous,
                  award.image == award.id + ".png" else { throw Failure.invalidCatalog }
            previous = award.thresholdSeconds
        }
        return catalog.awards
    }
}

/// One in-process streak. Only earned IDs persist; no old start time is restored.
@MainActor
public final class AwakeSession {
    private static let earnedKey = "awards.earnedIDs.v1"
    private static let secondsPerDay = 86400
    public let awards: [CaffeineAward]
    public private(set) var earnedIDs: Set<String>
    private let defaults: UserDefaults?
    private let now: () -> TimeInterval
    private var startedAt: TimeInterval?
    private var sleeping = false

    public init(awards: [CaffeineAward], defaults: UserDefaults? = nil,
                now: @escaping () -> TimeInterval = { ProcessInfo.processInfo.systemUptime }) {
        self.awards = awards
        self.defaults = defaults
        self.now = now
        earnedIDs = Set(defaults?.stringArray(forKey: Self.earnedKey) ?? []).intersection(awards.map(\.id))
    }

    public var elapsed: TimeInterval { startedAt.map { max(0, now() - $0) } ?? 0 }
    public var durationLabel: String {
        let seconds = Int(elapsed)
        let days = seconds / Self.secondsPerDay
        let clock = String(format: "%02d:%02d:%02d", (seconds % Self.secondsPerDay) / 3600, (seconds % 3600) / 60, seconds % 60)
        return days > 0 ? "\(days)d \(clock)" : clock
    }

    /// Call with actual owned assertion state, including after failed operations.
    public func update(active: Bool) {
        if startedAt != nil { unlockReachedAwards() }
        if active && !sleeping {
            if startedAt == nil { startedAt = now() }
        } else { startedAt = nil }
    }

    private func unlockReachedAwards() {
        let reached = Set(awards.filter { elapsed >= $0.thresholdSeconds }.map(\.id))
        let updated = earnedIDs.union(reached)
        guard updated != earnedIDs else { return }
        earnedIDs = updated
        defaults?.set(earnedIDs.sorted(), forKey: Self.earnedKey)
    }

    public func systemWillSleep() {
        update(active: false)
        sleeping = true
    }
    public func systemDidWake(active: Bool) {
        sleeping = false
        update(active: active)
    }
}
