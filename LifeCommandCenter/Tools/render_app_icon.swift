import AppKit
import Foundation

let size = 1024
guard CommandLine.arguments.count == 3 else {
    fatalError("Pass the output PNG path and accent color name")
}
let outputPath = CommandLine.arguments[1]
let paletteName = CommandLine.arguments[2]
let palette: (dark: NSColor, light: NSColor, card: NSColor) = {
    switch paletteName {
    case "Blue":
        (NSColor(calibratedRed: 0.06, green: 0.25, blue: 0.49, alpha: 1), NSColor(calibratedRed: 0.18, green: 0.52, blue: 0.86, alpha: 1), NSColor(calibratedRed: 0.08, green: 0.34, blue: 0.66, alpha: 1))
    case "Indigo":
        (NSColor(calibratedRed: 0.19, green: 0.20, blue: 0.48, alpha: 1), NSColor(calibratedRed: 0.39, green: 0.40, blue: 0.82, alpha: 1), NSColor(calibratedRed: 0.27, green: 0.27, blue: 0.62, alpha: 1))
    case "Purple":
        (NSColor(calibratedRed: 0.32, green: 0.16, blue: 0.45, alpha: 1), NSColor(calibratedRed: 0.61, green: 0.34, blue: 0.78, alpha: 1), NSColor(calibratedRed: 0.43, green: 0.22, blue: 0.59, alpha: 1))
    case "Pink":
        (NSColor(calibratedRed: 0.47, green: 0.17, blue: 0.32, alpha: 1), NSColor(calibratedRed: 0.86, green: 0.38, blue: 0.59, alpha: 1), NSColor(calibratedRed: 0.61, green: 0.23, blue: 0.42, alpha: 1))
    case "Orange":
        (NSColor(calibratedRed: 0.51, green: 0.23, blue: 0.08, alpha: 1), NSColor(calibratedRed: 0.94, green: 0.51, blue: 0.18, alpha: 1), NSColor(calibratedRed: 0.68, green: 0.32, blue: 0.10, alpha: 1))
    case "Teal":
        (NSColor(calibratedRed: 0.06, green: 0.31, blue: 0.32, alpha: 1), NSColor(calibratedRed: 0.18, green: 0.63, blue: 0.62, alpha: 1), NSColor(calibratedRed: 0.09, green: 0.43, blue: 0.43, alpha: 1))
    default:
        (NSColor(calibratedRed: 0.11, green: 0.24, blue: 0.20, alpha: 1), NSColor(calibratedRed: 0.30, green: 0.48, blue: 0.38, alpha: 1), NSColor(calibratedRed: 0.17, green: 0.34, blue: 0.28, alpha: 1))
    }
}()
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
    palette.dark,
    palette.light
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
palette.card.setFill()
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
palette.light.setFill()
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
try png.write(to: URL(fileURLWithPath: outputPath))
