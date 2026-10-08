import AppKit
import CaffeineCore

@main @MainActor
enum CaffeineApp {
    static func main() {
        if CommandLine.arguments.contains("--self-test") {
            do { try RuntimeCheck.run(); exit(0) }
            catch { FileHandle.standardError.write(Data("Caffeine self-test failed: \(error)\n".utf8)); exit(1) }
        }
        let app = NSApplication.shared
        // One menu-bar instance; restore preferences, never previous assertion IDs.
        if NSRunningApplication.runningApplications(withBundleIdentifier: "personal.harinaralasetty.Caffeine").contains(where: { $0.processIdentifier != getpid() }) { return }
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
    }
    func applicationWillTerminate(_ notification: Notification) {
        controller?.shutdown()
    }
}
