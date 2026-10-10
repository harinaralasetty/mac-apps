import Foundation
import Darwin

public struct AwakeMenuState: Equatable, Sendable {
    public let canTurnOn: Bool
    public let canTurnOff: Bool
    public let steaming: Bool
    public let title: String
    public init(appActive: Bool, cliActive: Bool, otherActive: Bool = false) {
        steaming = appActive || cliActive
        canTurnOn = !steaming
        canTurnOff = steaming
        var text = steaming ? "Caffeinate UI: On" : "Caffeinate UI: Off"
        if cliActive { text += " — CLI caffeinate active" }
        else if !appActive && otherActive { text += " — other apps prevent idle sleep" }
        title = text
    }
}

public struct CLIStopError: LocalizedError {
    public let issues: [String]
    public var errorDescription: String? { issues.joined(separator: "\n") }
}

/// Identity and workload checks apply to one PID, never its shell or process group.
public struct CLIProcessIdentity: Equatable, Sendable {
    public let pid: Int32
    public let uid: UInt32
    public let parentPID: Int32
    public let startSeconds: UInt64
    public let startMicroseconds: UInt64
    public let executable: String
    public let argumentWords: [String]
    public let hasChildren: Bool
    public let shellOrDetached: Bool
    public var birth: CLIProcessBirth { CLIProcessBirth(pid: pid, seconds: startSeconds, microseconds: startMicroseconds) }

    public func protectedReason(userID: UInt32) -> String? {
        guard pid > 1, uid == userID, executable == "/usr/bin/caffeinate" else {
            return "not this user's /usr/bin/caffeinate"
        }
        guard shellOrDetached else { return "owned by another application or an unverified parent" }
        guard !hasChildren else { return "has a child workload; stop it from its Terminal session" }
        guard Self.hasStandaloneArguments(argumentWords) else {
            return "wraps a command, watches a job, or has unrecognized arguments; stop it from its Terminal session"
        }
        return nil
    }

    static func hasStandaloneArguments(_ words: [String]) -> Bool {
        guard let command = words.first, command == "/usr/bin/caffeinate" || command == "caffeinate" else { return false }
        var index = 1
        while index < words.count {
            let word = words[index]
            if word == "--" { return index == words.count - 1 }
            guard word.hasPrefix("-"), word.count > 1 else { return false }
            let flags = Array(word.dropFirst())
            var offset = 0
            while offset < flags.count {
                let flag = flags[offset]
                if "dismu".contains(flag) { offset += 1; continue }
                // -w belongs to a workload; never stop its monitor here.
                guard flag == "t" else { return false }
                let value: String
                if offset + 1 < flags.count { value = String(flags[(offset + 1)...]) }
                else {
                    index += 1
                    guard index < words.count else { return false }
                    value = words[index]
                }
                guard let seconds = Double(value), seconds.isFinite, seconds >= 0 else { return false }
                break
            }
            index += 1
        }
        return true
    }
}

/// Explicit authorization for a detached process must match its birth, not just its PID.
public struct CLIProcessBirth: Hashable, Sendable {
    public let pid: Int32
    public let seconds: UInt64
    public let microseconds: UInt64
}

@MainActor public protocol CLIProcessAccess {
    func inspect(_ pid: Int32) throws -> CLIProcessIdentity?
    func terminate(_ expected: CLIProcessIdentity) throws
}

@MainActor public struct MacCLIProcessAccess: CLIProcessAccess {
    private let authorizedDetached: Set<CLIProcessBirth>
    public init(authorizedDetached: Set<CLIProcessBirth> = []) { self.authorizedDetached = authorizedDetached }
    private func info(_ pid: Int32) throws -> proc_bsdinfo? {
        var value = proc_bsdinfo()
        let size = Int32(MemoryLayout<proc_bsdinfo>.size)
        let result = proc_pidinfo(pid, PROC_PIDTBSDINFO, 0, &value, size)
        if result == 0 && (errno == ESRCH || errno == ENOENT) { return nil }
        guard result == size else { throw CLIStopError(issues: ["PID \(pid): process identity unavailable (\(errno))."] ) }
        return value.pbi_status == 5 ? nil : value // SZOMB: already exited.
    }
    private func path(_ pid: Int32) throws -> String {
        var buffer = [CChar](repeating: 0, count: Int(MAXPATHLEN) * 4)
        guard proc_pidpath(pid, &buffer, UInt32(buffer.count)) > 0 else {
            throw CLIStopError(issues: ["PID \(pid): executable unavailable (\(errno))."])
        }
        return String(decoding: buffer.prefix { $0 != 0 }.map { UInt8(bitPattern: $0) }, as: UTF8.self)
    }
    public func inspect(_ pid: Int32) throws -> CLIProcessIdentity? {
        guard let before = try info(pid) else { return nil }
        let executable = try path(pid)
        // ps requests arguments only, never the process environment.
        let query = Process()
        query.executableURL = URL(fileURLWithPath: "/bin/ps")
        query.arguments = ["-ww", "-p", String(pid), "-o", "args="]
        let output = Pipe()
        query.standardOutput = output
        query.standardError = FileHandle.nullDevice
        try query.run()
        let data = output.fileHandleForReading.readDataToEndOfFile()
        query.waitUntilExit()
        guard let after = try info(pid) else { return nil }
        guard query.terminationStatus == 0,
              before.pbi_start_tvsec == after.pbi_start_tvsec,
              before.pbi_start_tvusec == after.pbi_start_tvusec,
              before.pbi_uid == after.pbi_uid, before.pbi_ppid == after.pbi_ppid,
              executable == (try path(pid)) else {
            throw CLIStopError(issues: ["PID \(pid): identity changed while inspecting; left running."])
        }
        var children = [Int32](repeating: 0, count: 1)
        let childBytes = proc_listchildpids(pid, &children, Int32(MemoryLayout<Int32>.size))
        guard childBytes >= 0 else { throw CLIStopError(issues: ["PID \(pid): child workload check unavailable."]) }
        let parent = Int32(after.pbi_ppid)
        let birth = CLIProcessBirth(pid: pid, seconds: after.pbi_start_tvsec, microseconds: after.pbi_start_tvusec)
        // launchd adoption loses the original owner. Unknown detached processes
        // stay protected unless this exact birth was explicitly authorized.
        var shellOrDetached = parent == 1 && authorizedDetached.contains(birth)
        if parent > 1, let parentInfo = try info(parent) {
            let shells: Set<String> = ["/bin/zsh", "/bin/bash", "/bin/sh", "/bin/ksh", "/bin/csh", "/bin/tcsh", "/opt/homebrew/bin/fish", "/usr/local/bin/fish"]
            let parentPath = try path(parent)
            shellOrDetached = parentInfo.pbi_uid == getuid() && parentInfo.e_tdev != UInt32.max && shells.contains(parentPath)
        }
        return CLIProcessIdentity(pid: pid, uid: after.pbi_uid, parentPID: parent,
                                  startSeconds: after.pbi_start_tvsec, startMicroseconds: after.pbi_start_tvusec,
                                  executable: executable,
                                  argumentWords: String(decoding: data, as: UTF8.self).split(whereSeparator: \.isWhitespace).map(String.init),
                                  hasChildren: childBytes > 0, shellOrDetached: shellOrDetached)
    }
    public func terminate(_ expected: CLIProcessIdentity) throws {
        guard let current = try inspect(expected.pid) else { return }
        guard current == expected, current.protectedReason(userID: getuid()) == nil else {
            throw CLIStopError(issues: ["PID \(expected.pid): identity or workload changed; left running."])
        }
        guard kill(expected.pid, SIGTERM) == 0 || errno == ESRCH else {
            throw CLIStopError(issues: ["PID \(expected.pid): termination failed (\(errno)); left running."])
        }
    }
}

@MainActor public protocol CLISessionStopping {
    func snapshot() throws -> AssertionSnapshot
    func stop(_ assertions: [SleepAssertion]) async -> [String]
}

@MainActor public struct StandaloneCLIStopper: CLISessionStopping {
    private let processes: any CLIProcessAccess
    private let read: () throws -> AssertionSnapshot
    private let userID: UInt32
    public init(processes: any CLIProcessAccess = MacCLIProcessAccess(), userID: UInt32 = getuid(),
                read: @escaping () throws -> AssertionSnapshot = { try AssertionSnapshot.read() }) {
        self.processes = processes; self.read = read; self.userID = userID
    }
    public func snapshot() throws -> AssertionSnapshot { try read() }
    public func stop(_ assertions: [SleepAssertion]) async -> [String] {
        var issues: [String] = []
        for pid in Set(assertions.map(\.pid)).sorted() {
            do {
                guard let identity = try processes.inspect(pid) else { continue }
                if let reason = identity.protectedReason(userID: userID) {
                    issues.append("PID \(pid): \(reason); left running."); continue
                }
                let expected = assertions.filter { $0.pid == pid }
                let fresh = try read().entries
                guard expected.contains(where: { fresh.contains($0) }) else { continue }
                // The backend rechecks the complete identity immediately before SIGTERM.
                try processes.terminate(identity)
                var ended = false
                for _ in 0..<20 {
                    if !(try read().entries.contains { $0.pid == pid && $0.isCaffeinate }) { ended = true; break }
                    try await Task.sleep(for: .milliseconds(50))
                }
                if !ended { issues.append("PID \(pid): still holds sleep assertions after SIGTERM; no force kill was attempted.") }
            } catch { issues.append("PID \(pid): \(error.localizedDescription)") }
        }
        return issues
    }
}

extension AwakeController {
    /// Explicit Off includes safe standalone CLI sessions. Quit still releases only our IDs.
    public func turnOffAll(using stopper: any CLISessionStopping) async throws {
        var issues: [String] = []
        var current: [SleepAssertion] = []
        do {
            let snapshot = try stopper.snapshot()
            observeExternalAssertions(snapshot.external(to: getpid()), onACPower: snapshot.onACPower)
            current = externalCaffeinate
        } catch { issues.append("CLI status unavailable: \(error.localizedDescription)") }
        do { try turnOff() } catch { issues.append(error.localizedDescription) }
        issues += await stopper.stop(current)
        do {
            let snapshot = try stopper.snapshot()
            observeExternalAssertions(snapshot.external(to: getpid()), onACPower: snapshot.onACPower)
        } catch { issues.append("CLI status unavailable after Off: \(error.localizedDescription)") }
        if !issues.isEmpty { throw CLIStopError(issues: issues) }
    }
}
