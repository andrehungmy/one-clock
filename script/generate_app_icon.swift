#!/usr/bin/env swift
//
// Generates the One Clock app icon: a macOS squircle with a night-blue
// gradient, a warm dial, a single hand, and an orange progress arc — one
// clock, one sprint. Outputs a 1024×1024 master PNG.
//
// Usage: swift script/generate_app_icon.swift <output.png>

import AppKit

guard CommandLine.arguments.count == 2 else {
    fputs("usage: generate_app_icon.swift <output.png>\n", stderr)
    exit(1)
}
let outputPath = CommandLine.arguments[1]

let canvas = 1024
guard let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil,
    pixelsWide: canvas,
    pixelsHigh: canvas,
    bitsPerSample: 8,
    samplesPerPixel: 4,
    hasAlpha: true,
    isPlanar: false,
    colorSpaceName: .deviceRGB,
    bytesPerRow: 0,
    bitsPerPixel: 0
) else {
    fputs("error: could not create bitmap\n", stderr)
    exit(1)
}

NSGraphicsContext.saveGraphicsState()
guard let nsContext = NSGraphicsContext(bitmapImageRep: rep) else {
    fputs("error: could not create graphics context\n", stderr)
    exit(1)
}
NSGraphicsContext.current = nsContext
let ctx = nsContext.cgContext

func rgb(_ hex: UInt32, alpha: CGFloat = 1) -> CGColor {
    CGColor(
        red: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

let center = CGPoint(x: 512, y: 512)

// Squircle background (Big Sur grid: 824 pt shape centered in 1024).
let iconRect = CGRect(x: 100, y: 100, width: 824, height: 824)
let squircle = NSBezierPath(roundedRect: iconRect, xRadius: 186, yRadius: 186)

ctx.saveGState()
squircle.addClip()
let backgroundGradient = CGGradient(
    colorsSpace: CGColorSpaceCreateDeviceRGB(),
    colors: [rgb(0x35406B), rgb(0x141A30)] as CFArray,
    locations: [0, 1]
)!
ctx.drawLinearGradient(
    backgroundGradient,
    start: CGPoint(x: 512, y: 924),
    end: CGPoint(x: 512, y: 100),
    options: []
)
ctx.restoreGState()

// Dial with a soft drop shadow.
let dialRadius: CGFloat = 272
ctx.saveGState()
ctx.setShadow(
    offset: CGSize(width: 0, height: -16),
    blur: 44,
    color: rgb(0x000000, alpha: 0.38)
)
ctx.setFillColor(rgb(0xF7F4EC))
ctx.fillEllipse(in: CGRect(
    x: center.x - dialRadius,
    y: center.y - dialRadius,
    width: dialRadius * 2,
    height: dialRadius * 2
))
ctx.restoreGState()

// Progress arc: starts at 12, sweeps 225° clockwise.
let arcRadius: CGFloat = 206
let arcStart: CGFloat = .pi / 2
let arcEnd: CGFloat = .pi / 2 - (225 * .pi / 180)
ctx.setStrokeColor(rgb(0xFF9F0A))
ctx.setLineWidth(56)
ctx.setLineCap(.round)
ctx.addArc(center: center, radius: arcRadius, startAngle: arcStart, endAngle: arcEnd, clockwise: true)
ctx.strokePath()

// The single hand points at the arc's end.
let handLength: CGFloat = 150
let handTip = CGPoint(
    x: center.x + cos(arcEnd) * handLength,
    y: center.y + sin(arcEnd) * handLength
)
ctx.setStrokeColor(rgb(0x1C2440))
ctx.setLineWidth(34)
ctx.setLineCap(.round)
ctx.move(to: center)
ctx.addLine(to: handTip)
ctx.strokePath()

// Center hub.
ctx.setFillColor(rgb(0x1C2440))
ctx.fillEllipse(in: CGRect(x: center.x - 30, y: center.y - 30, width: 60, height: 60))
ctx.setFillColor(rgb(0xF7F4EC))
ctx.fillEllipse(in: CGRect(x: center.x - 11, y: center.y - 11, width: 22, height: 22))

NSGraphicsContext.restoreGraphicsState()

guard let png = rep.representation(using: .png, properties: [:]) else {
    fputs("error: could not encode PNG\n", stderr)
    exit(1)
}

do {
    try png.write(to: URL(fileURLWithPath: outputPath))
    print("wrote \(outputPath)")
} catch {
    fputs("error: \(error.localizedDescription)\n", stderr)
    exit(1)
}
