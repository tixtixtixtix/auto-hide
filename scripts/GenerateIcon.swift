import AppKit

// Build-time artwork only. The app itself has no custom drawing or animations.
let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: pixels, pixelsHigh: pixels,
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true,
            isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        )!
        NSGraphicsContext.saveGraphicsState()
        let context = NSGraphicsContext(bitmapImageRep: bitmap)!
        NSGraphicsContext.current = context
        context.cgContext.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)

        let background = NSBezierPath(
            roundedRect: NSRect(x: 104, y: 104, width: 816, height: 816),
            xRadius: 182, yRadius: 182
        )
        NSGraphicsContext.saveGraphicsState()
        let shadow = NSShadow()
        shadow.shadowColor = NSColor.black.withAlphaComponent(0.22)
        shadow.shadowBlurRadius = 24
        shadow.shadowOffset = NSSize(width: 0, height: -12)
        shadow.set()
        NSColor.systemBlue.setFill()
        background.fill()
        NSGraphicsContext.restoreGraphicsState()

        NSGradient(colors: [
            NSColor(srgbRed: 0.08, green: 0.67, blue: 0.98, alpha: 1),
            NSColor(srgbRed: 0.12, green: 0.29, blue: 0.87, alpha: 1)
        ])!.draw(in: background, angle: -65)

        let rearWindow = NSBezierPath(
            roundedRect: NSRect(x: 248, y: 424, width: 408, height: 300),
            xRadius: 44, yRadius: 44
        )
        rearWindow.lineWidth = 30
        NSColor.white.withAlphaComponent(0.48).setStroke()
        rearWindow.stroke()

        let frontWindow = NSBezierPath(
            roundedRect: NSRect(x: 368, y: 292, width: 408, height: 300),
            xRadius: 44, yRadius: 44
        )
        frontWindow.lineWidth = 32
        NSColor.white.setStroke()
        frontWindow.stroke()
        let titleBar = NSBezierPath()
        titleBar.move(to: NSPoint(x: 375, y: 514))
        titleBar.line(to: NSPoint(x: 769, y: 514))
        titleBar.lineWidth = 24
        titleBar.stroke()

        let slash = NSBezierPath()
        slash.move(to: NSPoint(x: 260, y: 764))
        slash.line(to: NSPoint(x: 790, y: 244))
        slash.lineCapStyle = .round
        slash.lineWidth = 72
        NSColor(srgbRed: 0.13, green: 0.43, blue: 0.92, alpha: 1).setStroke()
        slash.stroke()
        slash.lineWidth = 34
        NSColor.white.setStroke()
        slash.stroke()

        NSGraphicsContext.restoreGraphicsState()
        let suffix = scale == 2 ? "@2x" : ""
        let url = output.appendingPathComponent("icon_\(size)x\(size)\(suffix).png")
        try bitmap.representation(using: .png, properties: [:])!.write(to: url)
    }
}
print("Generated macOS app icon.")
