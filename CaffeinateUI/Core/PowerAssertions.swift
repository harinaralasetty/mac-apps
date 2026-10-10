import Foundation
import IOKit.pwr_mgt
import IOKit.ps

public struct PowerError: LocalizedError {
    let operation: String
    let code: IOReturn
    public var errorDescription: String? { "\(operation) failed (\(code))." }
}

@MainActor
public struct PowerAssertions: AssertionBackend {
    public init() {}
    public func create(_ mode: AwakeMode) throws -> UInt32 {
        var id: IOPMAssertionID = 0
        let type = mode == .system ? kIOPMAssertionTypePreventUserIdleSystemSleep : kIOPMAssertionTypePreventUserIdleDisplaySleep
        let result = IOPMAssertionCreateWithName(type as CFString, IOPMAssertionLevel(kIOPMAssertionLevelOn), "Caffeinate UI: \(mode.rawValue) awake" as CFString, &id)
        guard result == kIOReturnSuccess else { throw PowerError(operation: "Keep \(mode.rawValue) awake", code: result) }
        return id
    }
    public func release(_ id: UInt32) throws {
        let result = IOPMAssertionRelease(id)
        guard result == kIOReturnSuccess else { throw PowerError(operation: "Release awake assertion", code: result) }
    }
}

public struct SleepAssertion: Equatable, Sendable {
    public let pid: Int32
    public let id: UInt32
    public let type: String
    public let name: String
    public let startedAt: Date?
    public let globalUniqueID: UInt64?
    public init(pid: Int32, id: UInt32, type: String, name: String, startedAt: Date? = nil, globalUniqueID: UInt64? = nil) {
        self.pid = pid; self.id = id; self.type = type; self.name = name
        self.startedAt = startedAt; self.globalUniqueID = globalUniqueID
    }
    public var keepsSystemAwake: Bool {
        type == kIOPMAssertionTypePreventUserIdleSystemSleep || type == kIOPMAssertionTypePreventSystemSleep
    }
    public var keepsDisplayAwake: Bool { type == kIOPMAssertionTypePreventUserIdleDisplaySleep }
    /// Count the CLI tool's active system/display assertions, never unrelated apps.
    public var isCaffeinate: Bool { name == "caffeinate command-line tool" }
}

public struct AssertionSnapshot: Sendable {
    public let entries: [SleepAssertion]
    public let onACPower: Bool
    public static func read() throws -> AssertionSnapshot {
        let power = IOPSCopyPowerSourcesInfo()?.takeRetainedValue()
        let onACPower = power.map { IOPSGetProvidingPowerSourceType($0).takeUnretainedValue() as String == kIOPSACPowerValue } ?? false
        var value: Unmanaged<CFDictionary>?
        let result = IOPMCopyAssertionsByProcess(&value)
        guard result == kIOReturnSuccess, let value else {
            throw PowerError(operation: "Read other sleep assertions", code: result)
        }
        let dictionary = value.takeRetainedValue() as NSDictionary
        var entries: [SleepAssertion] = []
        for (key, raw) in dictionary {
            guard let pid = key as? NSNumber, let assertions = raw as? [NSDictionary] else { continue }
            for assertion in assertions {
                guard let level = assertion[kIOPMAssertionLevelKey] as? NSNumber, level.intValue != 0,
                      let type = assertion[kIOPMAssertionTypeKey] as? String else { continue }
                let name = assertion[kIOPMAssertionNameKey] as? String ?? "Unnamed"
                let id = (assertion["AssertionId"] as? NSNumber)?.uint32Value ?? 0
                let entry = SleepAssertion(pid: pid.int32Value, id: id, type: type, name: name,
                                           startedAt: assertion["AssertStartWhen"] as? Date,
                                           globalUniqueID: (assertion["GlobalUniqueID"] as? NSNumber)?.uint64Value)
                if entry.keepsSystemAwake || entry.keepsDisplayAwake { entries.append(entry) }
            }
        }
        return AssertionSnapshot(entries: entries.sorted { ($0.pid, $0.id) < ($1.pid, $1.id) }, onACPower: onACPower)
    }
    public func external(to pid: Int32) -> [SleepAssertion] { entries.filter { $0.pid != pid } }
}
