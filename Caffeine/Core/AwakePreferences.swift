import Foundation

/// Stores choices independently of assertion IDs, which must never survive a process.
@MainActor
public final class AwakePreferences {
    private let defaults: UserDefaults
    public init(defaults: UserDefaults = .standard) { self.defaults = defaults }
    private func key(_ mode: AwakeMode) -> String { "keepAwake.\(mode.rawValue)" }
    public func isEnabled(_ mode: AwakeMode) -> Bool { defaults.bool(forKey: key(mode)) }
    public func set(_ mode: AwakeMode, enabled: Bool) { defaults.set(enabled, forKey: key(mode)) }
}
