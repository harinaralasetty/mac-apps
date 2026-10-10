import AppKit
import CaffeinateUICore

@main @MainActor
enum CaffeinateUIApp {
    static func main() {
        if let index = CommandLine.arguments.firstIndex(of: "--awards-ui-check"), CommandLine.arguments.count > index + 1 {
            do {
                try RuntimeCheck.awardsWindowCheck(outputDirectory: URL(fileURLWithPath: CommandLine.arguments[index + 1]))
                exit(0)
            } catch { FileHandle.standardError.write(Data("Awards UI check failed: \(error)\n".utf8)); exit(1) }
        }
        if CommandLine.arguments.contains("--self-test") {
            do { try RuntimeCheck.run(); exit(0) }
            catch { FileHandle.standardError.write(Data("Caffeinate UI self-test failed: \(error)\n".utf8)); exit(1) }
        }
        let app = NSApplication.shared
        // One menu-bar instance; restore preferences, never previous assertion IDs.
        if NSRunningApplication.runningApplications(withBundleIdentifier: Bundle.main.bundleIdentifier ?? "personal.harinaralasetty.Caffeine").contains(where: { $0.processIdentifier != getpid() }) { return }
        let delegate = AppDelegate()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        app.run()
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var controller: StatusBarController?
    func applicationDidFinishLaunching(_ notification: Notification) {
        controller = StatusBarController()
        if CommandLine.arguments.contains("--show-awards") { controller?.showAwards() }
    }
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        controller?.showAwards()
        return true
    }
    func applicationWillTerminate(_ notification: Notification) {
        controller?.shutdown()
    }
}
