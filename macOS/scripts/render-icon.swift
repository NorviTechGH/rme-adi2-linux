// Original vector artwork, rendered with AppKit; no RME or Apple brand assets.
import AppKit
import Foundation

let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
let resources = root.appendingPathComponent("Resources")
let asset = resources.appendingPathComponent("Assets.xcassets/AppIcon.appiconset")
let iconset = root.appendingPathComponent("build/AppIcon.iconset")
try FileManager.default.createDirectory(at: asset, withIntermediateDirectories: true)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

func render(_ size: Int) throws -> Data {
    let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    let context = NSGraphicsContext(bitmapImageRep: bitmap)!
    NSGraphicsContext.saveGraphicsState()
    NSGraphicsContext.current = context
    context.cgContext.scaleBy(x: CGFloat(size)/1024, y: CGFloat(size)/1024)
    let body = NSBezierPath(roundedRect: NSRect(x: 64, y: 64, width: 896, height: 896), xRadius: 196, yRadius: 196)
    let shadow = NSShadow(); shadow.shadowColor = NSColor.black.withAlphaComponent(0.3); shadow.shadowBlurRadius = 22; shadow.shadowOffset = NSSize(width: 0, height: -10)
    shadow.set()
    NSGradient(starting: NSColor(calibratedRed: 0.16, green: 0.20, blue: 0.27, alpha: 1), ending: NSColor(calibratedRed: 0.035, green: 0.07, blue: 0.13, alpha: 1))!.draw(in: body, angle: -90)
    NSShadow().set()
    NSColor.white.withAlphaComponent(0.10).setStroke(); body.lineWidth = 3; body.stroke()
    let center = NSPoint(x: 512, y: 555)
    for tick in 0..<25 {
        let a = (Double(tick) * 11.25 - 45) * .pi / 180
        let outer = NSPoint(x: center.x + 296*cos(a), y: center.y + 296*sin(a))
        let inner = NSPoint(x: center.x + 280*cos(a), y: center.y + 280*sin(a))
        let path = NSBezierPath(); path.move(to: inner); path.line(to: outer); path.lineWidth = 6; path.lineCapStyle = .round
        (tick < 17 ? NSColor(calibratedRed: 0.25, green: 0.76, blue: 0.98, alpha: 1) : NSColor.white.withAlphaComponent(0.2)).setStroke(); path.stroke()
    }
    let ring = NSBezierPath(ovalIn: NSRect(x: 272, y: 315, width: 480, height: 480))
    NSColor.black.withAlphaComponent(0.45).setFill(); ring.fill()
    let knob = NSBezierPath(ovalIn: NSRect(x: 290, y: 333, width: 444, height: 444))
    NSGradient(starting: NSColor(calibratedWhite: 0.38, alpha: 1), ending: NSColor(calibratedWhite: 0.13, alpha: 1))!.draw(in: knob, angle: -90)
    NSColor.white.withAlphaComponent(0.18).setStroke(); knob.lineWidth = 2; knob.stroke()
    let marker = NSBezierPath(); marker.move(to: NSPoint(x: 578, y: 641)); marker.line(to: NSPoint(x: 632, y: 710)); marker.lineWidth = 16; marker.lineCapStyle = .round
    NSColor(calibratedRed: 0.39, green: 0.84, blue: 1, alpha: 1).setStroke(); marker.stroke()
    let baseline = NSBezierPath(); baseline.move(to: NSPoint(x: 250, y: 218)); baseline.line(to: NSPoint(x: 774, y: 218)); baseline.lineWidth = 2
    NSColor.white.withAlphaComponent(0.20).setStroke(); baseline.stroke()
    let response = NSBezierPath(); response.move(to: NSPoint(x: 250, y: 222))
    response.curve(to: NSPoint(x: 415, y: 218), controlPoint1: NSPoint(x: 322, y: 222), controlPoint2: NSPoint(x: 353, y: 321))
    response.curve(to: NSPoint(x: 588, y: 218), controlPoint1: NSPoint(x: 478, y: 128), controlPoint2: NSPoint(x: 510, y: 218))
    response.curve(to: NSPoint(x: 774, y: 230), controlPoint1: NSPoint(x: 668, y: 218), controlPoint2: NSPoint(x: 697, y: 308))
    response.lineWidth = 12; response.lineCapStyle = .round
    NSColor(calibratedRed: 0.25, green: 0.76, blue: 0.98, alpha: 1).setStroke(); response.stroke()
    NSGraphicsContext.restoreGraphicsState()
    return bitmap.representation(using: .png, properties: [:])!
}
var images: [[String: String]] = []
for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = base * scale
        let filename = "icon_\(base)x\(base)\(scale == 2 ? "@2x" : "").png"
        let data = try render(pixels)
        try data.write(to: iconset.appendingPathComponent(filename))
        try data.write(to: asset.appendingPathComponent(filename))
        images.append(["filename": filename, "idiom": "mac", "scale": "\(scale)x", "size": "\(base)x\(base)"])
    }
}
let contents: [String: Any] = ["images": images, "info": ["author": "xcode", "version": 1]]
try JSONSerialization.data(withJSONObject: contents, options: [.prettyPrinted, .sortedKeys]).write(to: asset.appendingPathComponent("Contents.json"))
try render(1024).write(to: resources.appendingPathComponent("AppIcon.png"))
print("Rendered original artwork. Run iconutil -c icns build/AppIcon.iconset -o Resources/AppIcon.icns")
