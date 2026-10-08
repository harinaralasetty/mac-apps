import Foundation
import CaffeineCore

@MainActor
enum RuntimeCheck {
    enum Failure: Error { case check(String) }
    static func run() throws {
        let before = try AssertionSnapshot.read()
        // Capture existing caffeinate assertions, including assertions unrelated to us.
        let external = before.external(to: getpid()).filter { $0.name == "caffeinate command-line tool" }
        let suite = "CaffeineRuntimeCheck.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let controller = AwakeController(backend: PowerAssertions(), preferences: AwakePreferences(defaults: defaults))
        defer { try? controller.turnOff() }
        func verify(_ condition: Bool, _ message: String) throws {
            guard condition else { throw Failure.check(message) }
            print("PASS: \(message)")
        }
        try verify(!controller.isActive, "startup in normal mode")
        try controller.setSystemAwake(enabled: true)
        let system = try AssertionSnapshot.read().entries.filter { $0.pid == getpid() }
        try verify(system.contains { $0.keepsSystemAwake && $0.name == "Caffeine: system awake" }, "real system assertion acquired")
        try verify(!system.contains(where: \.keepsDisplayAwake), "system control leaves display independent")
        try controller.setDisplayAwake(enabled: true)
        try verify(try AssertionSnapshot.read().entries.contains { $0.pid == getpid() && $0.keepsDisplayAwake }, "real display assertion acquired")
        try controller.setDisplayAwake(enabled: false)
        let systemOnly = try AssertionSnapshot.read().entries.filter { $0.pid == getpid() }
        try verify(systemOnly.contains(where: \.keepsSystemAwake) && !systemOnly.contains(where: \.keepsDisplayAwake), "allow display sleep retains system assertion")
        try controller.setDisplayAwake(enabled: true)
        try controller.setSystemAwake(enabled: false)
        try verify(!AssertionSnapshot.read().entries.contains { $0.pid == getpid() }, "main switch off releases both assertions")
        try controller.setDisplayAwake(enabled: true)
        try verify(!AssertionSnapshot.read().entries.contains { $0.pid == getpid() }, "display preference alone creates no assertion")
        for _ in 0..<20 {
            try controller.setSystemAwake(enabled: true)
            try controller.setSystemAwake(enabled: false)
        }
        let after = try AssertionSnapshot.read()
        try verify(!after.entries.contains { $0.pid == getpid() }, "20 repeated toggles release all owned assertions")
        for assertion in external {
            try verify(after.entries.contains(assertion), "external assertion retained: PID \(assertion.pid), ID \(assertion.id), \(assertion.type)")
        }
        print("PASS: external snapshot excludes current PID")
    }
}
