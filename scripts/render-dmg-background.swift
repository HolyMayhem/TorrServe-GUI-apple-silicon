#!/usr/bin/env swift

import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
    fputs("Usage: render-dmg-background.swift <output.png>\n", stderr)
    exit(64)
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let canvasSize = NSSize(width: 720, height: 480)

guard let bitmap = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: Int(canvasSize.width),
    pixelsHigh: Int(canvasSize.height),
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    fputs("Could not create the DMG background bitmap.\n", stderr)
    exit(1)
}

bitmap.size = canvasSize
let context = NSGraphicsContext(bitmapImageRep: bitmap)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = context

let bounds = NSRect(origin: .zero, size: canvasSize)
let background = NSGradient(colors: [
    NSColor(calibratedRed: 0.075, green: 0.086, blue: 0.098, alpha: 1),
    NSColor(calibratedRed: 0.115, green: 0.145, blue: 0.135, alpha: 1),
    NSColor(calibratedRed: 0.055, green: 0.063, blue: 0.075, alpha: 1)
])!
background.draw(in: bounds, angle: -28)

let glow = NSGradient(colors: [
    NSColor(calibratedRed: 0.0, green: 0.94, blue: 0.38, alpha: 0.14),
    NSColor(calibratedRed: 0.0, green: 0.94, blue: 0.38, alpha: 0)
])!
glow.draw(
    fromCenter: NSPoint(x: 160, y: 295),
    radius: 0,
    toCenter: NSPoint(x: 160, y: 295),
    radius: 250,
    options: [.drawsBeforeStartingLocation, .drawsAfterEndingLocation]
)

let panelRect = NSRect(x: 44, y: 86, width: 632, height: 258)
let panel = NSBezierPath(roundedRect: panelRect, xRadius: 28, yRadius: 28)
NSGraphicsContext.saveGraphicsState()
let panelShadow = NSShadow()
panelShadow.shadowColor = NSColor.black.withAlphaComponent(0.35)
panelShadow.shadowBlurRadius = 30
panelShadow.shadowOffset = NSSize(width: 0, height: -10)
panelShadow.set()
NSColor.white.withAlphaComponent(0.065).setFill()
panel.fill()
NSGraphicsContext.restoreGraphicsState()
NSColor.white.withAlphaComponent(0.14).setStroke()
panel.lineWidth = 1
panel.stroke()

func drawText(
    _ text: String,
    in rect: NSRect,
    font: NSFont,
    color: NSColor,
    alignment: NSTextAlignment = .left
) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = alignment
    NSAttributedString(
        string: text,
        attributes: [
            .font: font,
            .foregroundColor: color,
            .paragraphStyle: paragraph
        ]
    ).draw(in: rect)
}

let bolt = NSBezierPath()
bolt.move(to: NSPoint(x: 61, y: 429))
bolt.line(to: NSPoint(x: 49, y: 411))
bolt.line(to: NSPoint(x: 58, y: 411))
bolt.line(to: NSPoint(x: 53, y: 397))
bolt.line(to: NSPoint(x: 72, y: 417))
bolt.line(to: NSPoint(x: 62, y: 417))
bolt.close()
NSColor(calibratedRed: 0.0, green: 0.94, blue: 0.38, alpha: 0.9).setFill()
bolt.fill()

drawText(
    "TorrServer",
    in: NSRect(x: 82, y: 397, width: 300, height: 34),
    font: .systemFont(ofSize: 25, weight: .semibold),
    color: .white
)
drawText(
    "Drag TorrServer to Applications",
    in: NSRect(x: 45, y: 365, width: 630, height: 24),
    font: .systemFont(ofSize: 14, weight: .regular),
    color: NSColor.white.withAlphaComponent(0.62),
    alignment: .center
)

let arrow = NSBezierPath()
arrow.move(to: NSPoint(x: 304, y: 223))
arrow.line(to: NSPoint(x: 416, y: 223))
arrow.move(to: NSPoint(x: 397, y: 238))
arrow.line(to: NSPoint(x: 416, y: 223))
arrow.line(to: NSPoint(x: 397, y: 208))
arrow.lineCapStyle = .round
arrow.lineJoinStyle = .round
arrow.lineWidth = 3
NSColor.white.withAlphaComponent(0.48).setStroke()
arrow.stroke()

drawText(
    "HOLY MAYHEM  •  macOS",
    in: NSRect(x: 44, y: 28, width: 632, height: 18),
    font: .systemFont(ofSize: 10, weight: .medium),
    color: NSColor.white.withAlphaComponent(0.34),
    alignment: .center
)

NSGraphicsContext.restoreGraphicsState()

guard let pngData = bitmap.representation(using: .png, properties: [:]) else {
    fputs("Could not encode the DMG background.\n", stderr)
    exit(1)
}

try FileManager.default.createDirectory(
    at: outputURL.deletingLastPathComponent(),
    withIntermediateDirectories: true
)
try pngData.write(to: outputURL, options: .atomic)
