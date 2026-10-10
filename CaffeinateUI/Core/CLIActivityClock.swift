import Foundation

/// Reconciles one current CLI interval for display and award progress.
/// Historical sleep/AC conditions cannot be proven from an assertion timestamp.
@MainActor
public final class CLIActivityClock {
    private let now: () -> TimeInterval
    private let wallNow: () -> Date
    private var anchor: TimeInterval?
    private var identities: Set<UInt64> = []
    private var lastWall: Date?
    private var lastRead: TimeInterval?
    private var wallReliable = true
    private struct Claim: Codable {
        let assertionStart: Date
        let sessionStart: Date
        let claimedThrough: Date
    }
    private static let claimsKey = "awards.cliIntervals.v1"
    private let defaults: UserDefaults?
    private var claims: [String: Claim] = [:]
    private var checkpointTime: TimeInterval?


    public init(defaults: UserDefaults? = nil, now: (() -> TimeInterval)? = nil, wallNow: @escaping () -> Date = { Date() }) {
        self.defaults = defaults
        if let data = defaults?.data(forKey: Self.claimsKey),
           let saved = try? JSONDecoder().decode([String: Claim].self, from: data) {
            claims = saved
        }
        let reference = ContinuousClock.now
        self.now = now ?? {
            let elapsed = reference.duration(to: ContinuousClock.now).components
            return Double(elapsed.seconds) + Double(elapsed.attoseconds) / 1e18
        }
        self.wallNow = wallNow
    }
    public var elapsed: TimeInterval? { anchor.map { max(0, now() - $0) } }
    public var durationLabel: String? { elapsed.map { AwakeSession.durationLabel(seconds: $0) } }

    /// nil = no prior reliable identity; false = continuation cannot be proven.
    @discardableResult public func observe(_ entries: [SleepAssertion]) -> Bool? {
        let time = now(), wall = wallNow()
        let current = entries.compactMap { entry -> (id: UInt64, start: Date, age: TimeInterval)? in
            guard let id = entry.globalUniqueID, id != 0, let start = entry.startedAt else { return nil }
            let age = wall.timeIntervalSince(start)
            // -s depends on AC. Its earlier qualifying interval is unknowable.
            let historical = entry.type != "PreventSystemSleep" && age.isFinite && age >= 0
            let saved = claims[String(id)]
            let validSaved = historical && saved?.assertionStart == start
                && saved!.sessionStart <= start && saved!.claimedThrough <= wall
            let sessionStart = validSaved ? saved!.sessionStart : start
            return (id, start, historical ? wall.timeIntervalSince(sessionStart) : 0)
        }
        guard !current.isEmpty else {
            anchor = nil; identities = []; lastWall = nil; lastRead = nil; wallReliable = true
            return nil
        }
        if let lastWall, let lastRead,
           abs(wall.timeIntervalSince(lastWall) - (time - lastRead)) > 2 { wallReliable = false }
        let ids = Set(current.map(\.id))
        // Carry a departed assertion's earlier start only when an overlapping
        // assertion was actually observed in both snapshots. A past timestamp
        // on a newly seen PID cannot establish when a closed process ended.
        let overlap = !identities.isDisjoint(with: ids)
        let continuing: Bool? = identities.isEmpty ? nil : overlap
        if anchor == nil || continuing == false {
            anchor = time - (wallReliable ? current.map(\.age).max()! : 0)
        }
        // Store the interval itself, not an additive balance. Reopening uses
        // only records matching an assertion that is still active with the same
        // global ID and start. This also preserves a previously observed overlap.
        if wallReliable, let elapsed, identities != ids || checkpointTime == nil || time - checkpointTime! >= 60 {
            let sessionStart = wall.addingTimeInterval(-elapsed)
            for entry in current where entries.contains(where: { $0.globalUniqueID == entry.id && $0.type != "PreventSystemSleep" }) {
                guard entry.start <= wall else { continue }
                claims[String(entry.id)] = Claim(assertionStart: entry.start,
                    sessionStart: min(entry.start, sessionStart), claimedThrough: wall)
            }
            // Keep current identities and the most recent recovery records.
            let ordered = claims.sorted { $0.value.claimedThrough > $1.value.claimedThrough }
            claims = Dictionary(uniqueKeysWithValues: ordered.filter { ids.contains(UInt64($0.key) ?? 0) }
                + ordered.filter { !ids.contains(UInt64($0.key) ?? 0) }.prefix(128))
            if let data = try? JSONEncoder().encode(claims) { defaults?.set(data, forKey: Self.claimsKey) }
            checkpointTime = time
        }
        identities = ids; lastWall = wall; lastRead = time
        return continuing
    }
}
