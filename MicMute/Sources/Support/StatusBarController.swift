import AppKit

@MainActor
final class StatusBarController: NSObject, NSMenuDelegate {
    private static let refreshInterval: TimeInterval = 1

    private let microphone: MicrophoneMuteService
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private var refreshTimer: Timer?
    private var currentState: MicrophoneState = .unavailable("Checking microphone")

    init(microphone: MicrophoneMuteService) {
        self.microphone = microphone
        super.init()

        if let button = item.button {
            button.target = self
            button.action = #selector(statusItemClicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
            button.imagePosition = .imageOnly
        }

        refresh()
        refreshTimer = Timer.scheduledTimer(withTimeInterval: Self.refreshInterval, repeats: true) {
            [weak self] _ in
            Task { @MainActor [weak self] in self?.refresh() }
        }
    }

    isolated deinit {
        refreshTimer?.invalidate()
    }

    @objc private func statusItemClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showMenu()
            return
        }

        let result = microphone.toggle()
        updateDisplay(result)
        if case .unavailable(let message) = result {
            let alert = NSAlert()
            alert.messageText = "Could not toggle microphone"
            alert.informativeText = message
            alert.alertStyle = .warning
            alert.runModal()
            refresh()
        }
    }

    private func refresh() {
        let state = microphone.state()
        if state != currentState {
            updateDisplay(state)
        }
    }

    private func updateDisplay(_ state: MicrophoneState) {
        currentState = state
        guard let button = item.button else { return }

        let iconName: String
        let description: String
        switch state {
        case .muted:
            iconName = "MicMuted"
            description = "Microphone muted"
        case .live:
            iconName = "MicLive"
            description = "Microphone live"
        case .unavailable(let reason):
            iconName = "MicUnavailable"
            description = reason
        }

        let iconURL = Bundle.main.url(forResource: iconName, withExtension: "png")
        let icon = iconURL.flatMap(NSImage.init(contentsOf:))
        icon?.isTemplate = false
        icon?.size = NSSize(width: 18, height: 18)
        button.image = icon
        button.contentTintColor = nil
        button.toolTip = "\(description). Click to toggle; right-click for options."
        button.setAccessibilityLabel(description)
    }

    private func showMenu() {
        let menu = NSMenu()
        let status = NSMenuItem(title: statusTitle, action: nil, keyEquivalent: "")
        status.isEnabled = false
        menu.addItem(status)
        menu.addItem(.separator())
        let hint = NSMenuItem(title: "Click icon to toggle", action: nil, keyEquivalent: "")
        hint.isEnabled = false
        menu.addItem(hint)
        menu.addItem(.separator())

        let quit = NSMenuItem(title: "Quit MicMute", action: #selector(quitApp), keyEquivalent: "q")
        quit.target = self
        menu.addItem(quit)
        menu.delegate = self
        item.menu = menu
        item.button?.performClick(nil)
    }

    func menuDidClose(_ menu: NSMenu) {
        item.menu = nil
    }

    private var statusTitle: String {
        switch currentState {
        case .muted: "Microphone muted"
        case .live: "Microphone live"
        case .unavailable(let reason): reason
        }
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }
}
