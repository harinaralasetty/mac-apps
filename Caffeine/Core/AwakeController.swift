import Foundation

public enum AwakeMode: String, CaseIterable, Sendable {
    case system, display
}

@MainActor
public protocol AssertionBackend {
    func create(_ mode: AwakeMode) throws -> UInt32
    func release(_ id: UInt32) throws
}

/// Holds only IDs created by this controller. No process signals or global changes.
@MainActor
public final class AwakeController {
    private let backend: any AssertionBackend
    private let preferences: AwakePreferences?
    public private(set) var assertions: [AwakeMode: UInt32] = [:]
    public var isActive: Bool { !assertions.isEmpty }
    public func isEnabled(_ mode: AwakeMode) -> Bool { assertions[mode] != nil }

    public init(backend: any AssertionBackend, preferences: AwakePreferences? = nil) {
        self.backend = backend
        self.preferences = preferences
    }

    public func restorePreferences() throws {
        var firstError: (any Error)?
        for mode in AwakeMode.allCases where preferences?.isEnabled(mode) == true {
            do { try set(mode, enabled: true, persist: false) }
            catch { if firstError == nil { firstError = error } }
        }
        if let firstError { throw firstError }
    }

    public func set(_ mode: AwakeMode, enabled: Bool, persist: Bool = true) throws {
        if enabled {
            if assertions[mode] == nil { assertions[mode] = try backend.create(mode) }
        } else if let id = assertions[mode] {
            try backend.release(id)
            assertions[mode] = nil
        }
        if persist { preferences?.set(mode, enabled: enabled) }
    }

    public func turnOff(persist: Bool = true) throws {
        var firstError: (any Error)?
        for mode in AwakeMode.allCases {
            do { try set(mode, enabled: false, persist: persist) }
            catch { if firstError == nil { firstError = error } }
        }
        if let firstError { throw firstError }
    }
}
