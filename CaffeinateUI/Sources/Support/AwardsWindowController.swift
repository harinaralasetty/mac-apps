import AppKit
import SwiftUI
import CaffeinateUICore
import CoreImage

@MainActor
final class AwardsPresentation: ObservableObject {
    let awards: [CaffeinateUIAward]
    let images: [String: NSImage]
    let lockedImages: [String: NSImage]
    @Published var earnedIDs: Set<String> = []
    @Published var elapsed: TimeInterval = 0
    @Published var duration = "00:00:00"
    @Published var cliDuration: String?

    init(awards: [CaffeinateUIAward]) {
        self.awards = awards
        var images: [String: NSImage] = [:]
        var lockedImages: [String: NSImage] = [:]
        let context = CIContext(options: [.useSoftwareRenderer: true])
        for award in awards {
            if let resources = Bundle.main.resourceURL,
               let image = NSImage(contentsOf: resources.appendingPathComponent("Badges/\(award.image)")) {
                images[award.id] = image
                if let data = image.tiffRepresentation, let original = CIImage(data: data),
                   let filter = CIFilter(name: "CIColorControls") {
                    filter.setValue(original, forKey: kCIInputImageKey)
                    filter.setValue(0, forKey: kCIInputSaturationKey)
                    if let output = filter.outputImage, let grayscale = context.createCGImage(output, from: output.extent) {
                        lockedImages[award.id] = NSImage(cgImage: grayscale, size: image.size)
                    }
                }
            }
        }
        self.images = images
        self.lockedImages = lockedImages
    }

    func update(from session: AwakeSession) {
        earnedIDs = session.earnedIDs
        elapsed = session.elapsed
        duration = session.durationLabel
    }
}

struct AwardsView: View {
    @ObservedObject var presentation: AwardsPresentation
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("One streak. Twelve milestones.").font(.title2.bold())
                Text("\(presentation.earnedIDs.count) of \(presentation.awards.count) earned · \(presentation.cliDuration.map { "CLI session \($0)" } ?? "Awake streak \(presentation.duration)")")
                    .font(.subheadline.monospacedDigit())
                if presentation.cliDuration != nil {
                    Text("Award progress: \(presentation.duration). Includes earlier time from the current CLI session, which may include sleep. Overlaps count once.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Text("Caffeinate UI and qualifying CLI caffeinate sessions count. App-only sleep or no qualifying activity resets progress; earned awards stay saved.")
                    .font(.caption).foregroundStyle(.secondary)
            }.padding([.horizontal, .top], 20)
            ScrollView {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 160), spacing: 12)], spacing: 12) {
                    ForEach(presentation.awards, id: \.id) { award in
                        card(award)
                    }
                }.padding(20)
            }
        }.frame(minWidth: 400, minHeight: 420)
            .background(Color(nsColor: .windowBackgroundColor))
    }

    private func card(_ award: CaffeinateUIAward) -> some View {
        let earned = presentation.earnedIDs.contains(award.id)
        let progress = min(1, presentation.elapsed / award.thresholdSeconds)
        return VStack(spacing: 8) {
            if let image = earned ? presentation.images[award.id] : presentation.lockedImages[award.id] {
                Image(nsImage: image).resizable().scaledToFit().frame(height: 112)
                    .opacity(earned ? 1 : 0.75).accessibilityHidden(true)
            } else {
                Image(systemName: earned ? "checkmark.seal" : "lock.fill")
                    .font(.system(size: 52)).frame(height: 112).accessibilityHidden(true)
            }
            Text(award.title).font(.headline).multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
            Text(award.thresholdLabel).font(.caption).foregroundStyle(.secondary)
            Label(earned ? "Earned" : "Locked", systemImage: earned ? "checkmark.circle.fill" : "lock.fill")
                .font(.caption.bold()).foregroundStyle(earned ? Color.green : Color.secondary)
            if !earned {
                ProgressView(value: progress)
                    .accessibilityLabel("\(award.title) current streak progress")
                Text("\(Int(progress * 100))% of this milestone").font(.caption2).foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 225)
        .padding(12)
        .background(Color(nsColor: .controlBackgroundColor), in: RoundedRectangle(cornerRadius: 14))
        .accessibilityElement(children: .combine)
    }
}

@MainActor
final class AwardsWindowController {
    let presentation: AwardsPresentation
    private(set) var window: NSWindow?
    init(awards: [CaffeinateUIAward]) { presentation = AwardsPresentation(awards: awards) }

    @discardableResult
    func show(activate: Bool = true) -> NSWindow {
        if window == nil {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 640),
                                  styleMask: [.titled, .closable, .miniaturizable, .resizable],
                                  backing: .buffered, defer: false)
            window.title = "Caffeinate UI Awards"
            window.isReleasedWhenClosed = false
            window.isRestorable = false
            window.contentMinSize = NSSize(width: 400, height: 420)
            window.contentView = NSHostingView(rootView: AwardsView(presentation: presentation))
            window.center()
            self.window = window
        }
        let window = window!
        if activate {
            if window.isMiniaturized { window.deminiaturize(nil) }
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
        return window
    }
}
