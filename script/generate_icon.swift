import AppKit

// Local vector drawing; no downloaded artwork or executable components.
let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let iconset = output.appendingPathComponent("AppIcon.iconset", isDirectory: true)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
func render(_ pixels: Int) throws -> Data {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
        bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
        colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.saveGraphicsState()
    defer { NSGraphicsContext.restoreGraphicsState() }
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
    let transform = NSAffineTransform(); transform.scale(by: CGFloat(pixels) / 1024); transform.concat()
    let background = NSBezierPath(roundedRect: NSRect(x: 32, y: 32, width: 960, height: 960), xRadius: 216, yRadius: 216)
    NSGradient(starting: NSColor(calibratedRed: 0.93, green: 0.61, blue: 0.32, alpha: 1),
               ending: NSColor(calibratedRed: 0.58, green: 0.29, blue: 0.15, alpha: 1))!.draw(in: background, angle: -90)
    NSColor(calibratedWhite: 1, alpha: 0.95).setStroke()
    let handle = NSBezierPath(ovalIn: NSRect(x: 630, y: 325, width: 205, height: 230))
    handle.lineWidth = 48; handle.stroke()
    let cup = NSBezierPath()
    cup.move(to: NSPoint(x: 225, y: 590)); cup.line(to: NSPoint(x: 690, y: 590))
    cup.line(to: NSPoint(x: 650, y: 330))
    cup.curve(to: NSPoint(x: 560, y: 245), controlPoint1: NSPoint(x: 642, y: 275), controlPoint2: NSPoint(x: 606, y: 245))
    cup.line(to: NSPoint(x: 355, y: 245))
    cup.curve(to: NSPoint(x: 265, y: 330), controlPoint1: NSPoint(x: 309, y: 245), controlPoint2: NSPoint(x: 273, y: 275))
    cup.close(); NSColor(calibratedWhite: 1, alpha: 0.97).setFill(); cup.fill()
    NSColor(calibratedRed: 0.32, green: 0.16, blue: 0.09, alpha: 1).setFill()
    NSBezierPath(ovalIn: NSRect(x: 250, y: 555, width: 415, height: 50)).fill()
    NSColor(calibratedWhite: 1, alpha: 0.95).setStroke()
    let saucer = NSBezierPath(); saucer.lineWidth = 26; saucer.lineCapStyle = .round
    saucer.move(to: NSPoint(x: 210, y: 200)); saucer.line(to: NSPoint(x: 725, y: 200)); saucer.stroke()
    for x in [CGFloat(330), 455, 580] {
        let steam = NSBezierPath(); steam.lineWidth = 28; steam.lineCapStyle = .round
        steam.move(to: NSPoint(x: x, y: 655))
        steam.curve(to: NSPoint(x: x, y: 820), controlPoint1: NSPoint(x: x - 65, y: 710), controlPoint2: NSPoint(x: x + 65, y: 765))
        steam.stroke()
    }
    return bitmap.representation(using: .png, properties: [:])!
}
for size in [16, 32, 128, 256, 512] {
    try render(size).write(to: iconset.appendingPathComponent("icon_\(size)x\(size).png"))
    try render(size * 2).write(to: iconset.appendingPathComponent("icon_\(size)x\(size)@2x.png"))
}
try render(1024).write(to: output.appendingPathComponent("AppIcon.png"))
