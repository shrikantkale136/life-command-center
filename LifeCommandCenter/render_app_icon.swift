import AppKit
import Foundation

let size = 1024
guard CommandLine.arguments.count == 2 else {
    fatalError("Pass the output PNG path")
}
let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: size,
    pixelsHigh: size,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
)!
let graphics = NSGraphicsContext(bitmapImageRep: bitmap)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = graphics
graphics.imageInterpolation = .high

let canvas = NSRect(x: 0, y: 0, width: size, height: size)
NSGradient(colors: [
    NSColor(calibratedRed: 0.11, green: 0.24, blue: 0.20, alpha: 1),
    NSColor(calibratedRed: 0.30, green: 0.48, blue: 0.38, alpha: 1)
])!.draw(in: canvas, angle: 45)

// A soft, quiet glow gives the simple mark a little depth at small sizes.
NSColor.white.withAlphaComponent(0.045).setFill()
NSBezierPath(ovalIn: NSRect(x: 120, y: 380, width: 780, height: 780)).fill()

let house = NSBezierPath()
house.move(to: NSPoint(x: 512, y: 810))
house.line(to: NSPoint(x: 166, y: 526))
house.line(to: NSPoint(x: 249, y: 526))
house.line(to: NSPoint(x: 249, y: 252))
house.curve(to: NSPoint(x: 279, y: 222), controlPoint1: NSPoint(x: 249, y: 235), controlPoint2: NSPoint(x: 262, y: 222))
house.line(to: NSPoint(x: 745, y: 222))
house.curve(to: NSPoint(x: 775, y: 252), controlPoint1: NSPoint(x: 762, y: 222), controlPoint2: NSPoint(x: 775, y: 235))
house.line(to: NSPoint(x: 775, y: 526))
house.line(to: NSPoint(x: 858, y: 526))
house.close()
NSColor(calibratedRed: 0.98, green: 0.97, blue: 0.91, alpha: 1).setFill()
house.fill()

let card = NSBezierPath(roundedRect: NSRect(x: 334, y: 332, width: 356, height: 255), xRadius: 34, yRadius: 34)
NSColor(calibratedRed: 0.17, green: 0.34, blue: 0.28, alpha: 1).setFill()
card.fill()

let rowColor = NSColor(calibratedRed: 0.78, green: 0.85, blue: 0.77, alpha: 1)
for y: CGFloat in [520, 459, 398] {
    let dot = NSBezierPath(ovalIn: NSRect(x: 374, y: y - 7, width: 14, height: 14))
    rowColor.setFill()
    dot.fill()
    let line = NSBezierPath(roundedRect: NSRect(x: 411, y: y - 5, width: y == 398 ? 172 : 210, height: 10), xRadius: 5, yRadius: 5)
    rowColor.withAlphaComponent(0.9).setFill()
    line.fill()
}

// Warm completion badge: a clear task cue that remains legible on the icon grid.
let badgeRect = NSRect(x: 658, y: 236, width: 170, height: 170)
let badge = NSBezierPath(ovalIn: badgeRect)
NSColor(calibratedRed: 0.91, green: 0.66, blue: 0.35, alpha: 1).setFill()
badge.fill()
let check = NSBezierPath()
check.lineWidth = 22
check.lineCapStyle = .round
check.lineJoinStyle = .round
check.move(to: NSPoint(x: 705, y: 320))
check.line(to: NSPoint(x: 744, y: 282))
check.line(to: NSPoint(x: 787, y: 336))
NSColor.white.setStroke()
check.stroke()

graphics.flushGraphics()
NSGraphicsContext.restoreGraphicsState()
let png = bitmap.representation(using: .png, properties: [:])!
try png.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
