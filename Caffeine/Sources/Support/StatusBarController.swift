import AppKit
import CaffeineCore

@MainActor
final class StatusBarController: NSObject, NSMenuDelegate {
    private let awake = AwakeController(backend: PowerAssertions(), preferences: AwakePreferences())
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()
    private var timer: Timer?
    private var statusRow: NSMenuItem!
    private var systemRow: NSMenuItem!
    private var displayRow: NSMenuItem!
    private var displaySleepRow: NSMenuItem!
    private var externalRow: NSMenuItem!
    private var externalSystemRow: NSMenuItem!
    private var externalDisplayRow: NSMenuItem!
    private var lastError: String?

    override init() {
        super.init()
        menu.delegate = self
        statusRow = add("Caffeine: normal mode")
        menu.addItem(.separator())
        systemRow = add("Keep System Awake", action: #selector(toggleSystem))
        displayRow = add("Keep Display Awake", action: #selector(keepDisplayAwake))
        displaySleepRow = add("Allow Display Sleep", action: #selector(allowDisplaySleep))
        displayRow.indentationLevel = 1
        displaySleepRow.indentationLevel = 1
        menu.autoenablesItems = false
        menu.addItem(.separator())
        externalSystemRow = add("Other system assertions: none")
        externalDisplayRow = add("Other display assertions: none")
        externalRow = add("Other Sleep Assertions")
        menu.addItem(.separator())
        add("About Caffeine", action: #selector(about))
        add("Quit Caffeine", action: #selector(quit), key: "q")
        item.menu = menu
        item.button?.imagePosition = .imageOnly
        do { try awake.restorePreferences() }
        catch { lastError = error.localizedDescription }
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 3, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.refresh() }
        }
    }

    @discardableResult private func add(_ title: String, action: Selector? = nil, key: String = "") -> NSMenuItem {
        let row = NSMenuItem(title: title, action: action, keyEquivalent: key)
        row.target = action == nil ? nil : self
        row.isEnabled = action != nil
        menu.addItem(row)
        return row
    }

    func menuWillOpen(_ menu: NSMenu) { refresh() }

    private func refresh() {
        let title = awake.isActive ? "Caffeine: On" : "Caffeine: Off"
        statusRow.title = title
        systemRow.state = awake.isEnabled(.system) ? .on : .off
        displayRow.state = awake.isEnabled(.display) ? .on : .off
        displaySleepRow.state = awake.isEnabled(.system) && !awake.isEnabled(.display) ? .on : .off
        displayRow.isEnabled = awake.isEnabled(.system)
        displaySleepRow.isEnabled = awake.isEnabled(.system)
        item.button?.image = CupIcon.make(steaming: awake.isActive)
        item.button?.toolTip = "\(title). System \(awake.isEnabled(.system) ? "awake" : "normal"), display \(awake.isEnabled(.display) ? "awake" : "normal")."
        item.button?.setAccessibilityLabel(title)
        let details = NSMenu()
        do {
            let entries = try AssertionSnapshot.read().external(to: getpid())
            let system = entries.filter(\.keepsSystemAwake).count
            let display = entries.filter(\.keepsDisplayAwake).count
            externalSystemRow.title = system > 0 ? "Other apps also keep system awake (\(system))" : "No other system sleep assertions"
            externalDisplayRow.title = display > 0 ? "Other apps also keep display awake (\(display))" : "No other display sleep assertions"
            if !awake.isActive && (system > 0 || display > 0) {
                statusRow.title = "Caffeine: Off — other apps prevent idle sleep"
            }
            for entry in entries {
                let process = NSRunningApplication(processIdentifier: entry.pid)?.localizedName ?? (entry.name == "caffeinate command-line tool" ? "caffeinate" : "PID \(entry.pid)")
                let mode = entry.keepsDisplayAwake ? "display" : "system"
                let row = NSMenuItem(title: "\(process.prefix(16)): \(mode)", action: nil, keyEquivalent: "")
                row.toolTip = "PID \(entry.pid): \(entry.name) [\(entry.type)]"
                details.addItem(row)
            }
            if entries.isEmpty { details.addItem(NSMenuItem(title: "No other sleep assertions", action: nil, keyEquivalent: "")) }
        } catch {
            externalSystemRow.title = "Other assertions: unavailable"
            externalDisplayRow.title = "Could not read display status"
            details.addItem(NSMenuItem(title: "Status read failed", action: nil, keyEquivalent: ""))
        }
        if let lastError {
            let row = NSMenuItem(title: "Last action failed", action: nil, keyEquivalent: "")
            row.toolTip = lastError; details.addItem(row)
        }
        externalRow.submenu = details
        externalRow.isEnabled = true
    }

    private func perform(_ operation: () throws -> Void) {
        do { try operation(); lastError = nil }
        catch {
            lastError = error.localizedDescription
            let alert = NSAlert()
            alert.messageText = "Could not change awake mode"
            alert.informativeText = error.localizedDescription
            alert.runModal()
        }
        refresh()
    }
    @objc private func toggleSystem() { perform { try awake.setSystemAwake(enabled: !awake.isEnabled(.system)) } }
    @objc private func keepDisplayAwake() { perform { try awake.setDisplayAwake(enabled: true) } }
    @objc private func allowDisplaySleep() { perform { try awake.setDisplayAwake(enabled: false) } }
    @objc private func about() {
        let alert = NSAlert()
        alert.messageText = "Caffeine"
        alert.informativeText = "Keep System Awake is the main switch. While it is on, choose Keep Display Awake or Allow Display Sleep. Turning the main switch off releases both assertions. Other apps may still prevent idle sleep.\n\nThe display choice is remembered for the next time you enable system mode. Relaunch restores the main switch and chosen display option. Quit releases only Caffeine's assertions. Screen locking and security settings remain in effect. Lid closure, low battery and forced sleep can override idle-sleep assertions."
        alert.runModal()
    }
    @objc private func quit() { NSApp.terminate(nil) }
    func shutdown() { timer?.invalidate(); try? awake.turnOff(persist: false) }
}
