import AppKit
import CaffeineCore

@MainActor
final class StatusBarController: NSObject, NSMenuDelegate {
    private let awake: AwakeController
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let menu = NSMenu()
    private var timer: Timer?
    private var statusRow: NSMenuItem!
    private var streakRow: NSMenuItem!
    private var awardsRow: NSMenuItem!
    private var awardsWindow: AwardsWindowController!
    private var systemRow: NSMenuItem!
    private var displayRow: NSMenuItem!
    private var externalRow: NSMenuItem!
    private var externalSystemRow: NSMenuItem!
    private var externalDisplayRow: NSMenuItem!
    private var lastError: String?

    override init() {
        var catalogError: String?
        let awards: [CaffeineAward]
        do {
            guard let resources = Bundle.main.resourceURL else { throw AwardCatalog.Failure.invalidCatalog }
            awards = try AwardCatalog.read(from: resources.appendingPathComponent("Badges/catalog.json"))
        } catch {
            awards = []
            catalogError = "Badge catalog unavailable: \(error.localizedDescription)"
        }
        let session = AwakeSession(awards: awards, defaults: .standard)
        awake = AwakeController(backend: PowerAssertions(), preferences: AwakePreferences(), session: session,
                                cliClock: CLIActivityClock(defaults: .standard))
        super.init()
        lastError = catalogError
        menu.delegate = self
        statusRow = add("Caffeine: normal mode")
        streakRow = add("Awake streak: 00:00:00")
        streakRow.toolTip = "One uninterrupted session from Caffeine or CLI caffeinate. No qualifying assertions, quit/relaunch or system sleep resets it. Display sleep and screen lock do not."
        awardsWindow = AwardsWindowController(awards: session.awards)
        awardsRow = add("Show Awards…", action: #selector(showAwards))
        menu.addItem(.separator())
        add("Turn On", action: #selector(turnOn), key: "a")
        add("Turn Off", action: #selector(turnOff), key: "o")
        menu.addItem(.separator())
        systemRow = add("Keep System Awake", action: #selector(toggleSystem))
        displayRow = add("Keep Display Awake", action: #selector(toggleDisplay))
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
        let notifications = NSWorkspace.shared.notificationCenter
        notifications.addObserver(self, selector: #selector(systemWillSleep), name: NSWorkspace.willSleepNotification, object: nil)
        notifications.addObserver(self, selector: #selector(systemDidWake), name: NSWorkspace.didWakeNotification, object: nil)
        let tick = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.timerTick() }
        }
        // Common modes keep the timer visible while the menu is tracking.
        RunLoop.main.add(tick, forMode: .common)
        timer = tick
    }

    @discardableResult private func add(_ title: String, action: Selector? = nil, key: String = "") -> NSMenuItem {
        let row = NSMenuItem(title: title, action: action, keyEquivalent: key)
        row.target = action == nil ? nil : self
        row.isEnabled = action != nil
        menu.addItem(row)
        return row
    }

    func menuWillOpen(_ menu: NSMenu) { refresh() }

    private func timerTick() {
        refresh()
    }

    private func refreshSession() {
        guard let session = awake.session else { return }
        streakRow.title = awake.cliClock.durationLabel.map { "CLI session: \($0)" } ?? "Awake streak: \(session.durationLabel)"
        streakRow.toolTip = "Current CLI assertion time counts toward awards, including time before Caffeine opened. Recovered CLI time may include system sleep. Overlaps count once."
        awardsRow.title = "Show Awards… (\(session.earnedIDs.count)/\(session.awards.count))"
        awardsWindow.presentation.update(from: session)
        awardsWindow.presentation.cliDuration = awake.cliClock.durationLabel
    }

    @objc private func systemWillSleep() { awake.session?.systemWillSleep(); refreshSession() }
    @objc private func systemDidWake() { awake.session?.systemDidWake(active: awake.isSessionActive); refresh() }

    private func refresh() {
        var entries: [SleepAssertion] = []
        var snapshotError = false
        do {
            let snapshot = try AssertionSnapshot.read()
            entries = snapshot.external(to: getpid())
            awake.observeExternalAssertions(entries, onACPower: snapshot.onACPower)
        } catch {
            snapshotError = true
            awake.observeExternalAssertions([])
        }
        refreshSession()
        let title = awake.isActive ? "Caffeine: On" : (awake.isSessionActive ? "Caffeine: CLI caffeinate active" : "Caffeine: Off")
        statusRow.title = title
        systemRow.state = awake.isEnabled(.system) ? .on : .off
        displayRow.state = awake.isEnabled(.display) ? .on : .off
        item.button?.image = CupIcon.make(steaming: awake.isSessionActive)
        item.button?.toolTip = "\(title). App controls: system \(awake.isEnabled(.system) ? "on" : "off"), display \(awake.isEnabled(.display) ? "on" : "off")."
        item.button?.setAccessibilityLabel(title)
        let details = NSMenu()
        if !snapshotError {
            let system = entries.filter(\.keepsSystemAwake).count
            let display = entries.filter(\.keepsDisplayAwake).count
            externalSystemRow.title = system > 0 ? "Other apps also keep system awake (\(system))" : "No other system sleep assertions"
            externalDisplayRow.title = display > 0 ? "Other apps also keep display awake (\(display))" : "No other display sleep assertions"
            if !awake.isSessionActive && (system > 0 || display > 0) {
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
        } else {
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
    @objc func showAwards() { refresh(); awardsWindow.show() }
    @objc private func turnOn() { perform { try awake.set(.system, enabled: true) } }
    @objc private func turnOff() { perform { try awake.turnOff() } }
    @objc private func toggleSystem() { perform { try awake.set(.system, enabled: !awake.isEnabled(.system)) } }
    @objc private func toggleDisplay() { perform { try awake.set(.display, enabled: !awake.isEnabled(.display)) } }
    @objc private func about() {
        let alert = NSAlert()
        alert.messageText = "Caffeine"
        alert.informativeText = "Steam means Caffeine or CLI caffeinate holds a system or display sleep assertion. Turn On keeps the system awake; the display control is separate. Turn Off and Quit release only Caffeine's assertions. Other apps may still prevent idle sleep.\n\nAwake streak measures one uninterrupted session while either control or a CLI caffeinate system/display assertion is active. No qualifying assertions, Quit/relaunch or system sleep resets it; display sleep and locking do not. Earned awards stay saved locally.\n\nYour choices are restored after relaunch. Quit releases assertions without changing those choices. Login startup is managed by the project's login script. Screen locking and security settings remain in effect. Lid closure, low battery and forced sleep can override idle-sleep assertions."
        alert.runModal()
    }
    @objc private func quit() { NSApp.terminate(nil) }
    func shutdown() {
        timer?.invalidate()
        NSWorkspace.shared.notificationCenter.removeObserver(self)
        try? awake.turnOff(persist: false)
        awake.session?.update(active: false)
    }
}
