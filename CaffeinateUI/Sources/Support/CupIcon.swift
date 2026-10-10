import AppKit

enum CupIcon {
    /// Template artwork follows the menu bar appearance in light and dark mode.
    static func make(steaming: Bool) -> NSImage {
        let image = NSImage(size: NSSize(width: 22, height: 22), flipped: false) { _ in
            NSColor.black.setStroke()
            let cup = NSBezierPath()
            cup.lineWidth = 1.6
            cup.move(to: NSPoint(x: 4, y: 13))
            cup.line(to: NSPoint(x: 4, y: 7))
            cup.curve(to: NSPoint(x: 8, y: 3), controlPoint1: NSPoint(x: 4, y: 4), controlPoint2: NSPoint(x: 5, y: 3))
            cup.line(to: NSPoint(x: 12, y: 3))
            cup.curve(to: NSPoint(x: 16, y: 7), controlPoint1: NSPoint(x: 15, y: 3), controlPoint2: NSPoint(x: 16, y: 4))
            cup.line(to: NSPoint(x: 16, y: 13)); cup.close(); cup.stroke()
            let handle = NSBezierPath()
            handle.lineWidth = 1.6
            handle.move(to: NSPoint(x: 16, y: 12))
            handle.curve(to: NSPoint(x: 16, y: 6), controlPoint1: NSPoint(x: 22, y: 13), controlPoint2: NSPoint(x: 22, y: 5))
            handle.stroke()
            if steaming {
                for x in [6.0, 10.0, 14.0] {
                    let steam = NSBezierPath(); steam.lineWidth = 1.3
                    steam.move(to: NSPoint(x: x, y: 15))
                    steam.curve(to: NSPoint(x: x, y: 21), controlPoint1: NSPoint(x: x - 2, y: 17), controlPoint2: NSPoint(x: x + 2, y: 19))
                    steam.stroke()
                }
            }
            return true
        }
        image.isTemplate = true
        return image
    }
}
