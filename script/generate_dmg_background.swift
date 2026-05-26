#!/usr/bin/env swift
import AppKit

guard CommandLine.arguments.count == 2 else {
    fputs("Usage: generate_dmg_background.swift OUTPUT_PNG\n", stderr)
    exit(64)
}

let outputURL = URL(fileURLWithPath: CommandLine.arguments[1])
let canvasSize = NSSize(width: 760, height: 480)
let image = NSImage(size: canvasSize)

image.lockFocus()

NSColor(calibratedWhite: 0.965, alpha: 1).setFill()
NSBezierPath(rect: NSRect(origin: .zero, size: canvasSize)).fill()

let titleAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 28, weight: .semibold),
    .foregroundColor: NSColor.labelColor,
    .paragraphStyle: {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        return style
    }()
]

let subtitleAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 14, weight: .regular),
    .foregroundColor: NSColor.secondaryLabelColor,
    .paragraphStyle: {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        return style
    }()
]

let stepAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 13, weight: .medium),
    .foregroundColor: NSColor.secondaryLabelColor
]

let helperAttributes: [NSAttributedString.Key: Any] = [
    .font: NSFont.systemFont(ofSize: 12, weight: .regular),
    .foregroundColor: NSColor.tertiaryLabelColor,
    .paragraphStyle: {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        return style
    }()
]

"Install QuillLook".draw(
    in: NSRect(x: 0, y: 414, width: canvasSize.width, height: 34),
    withAttributes: titleAttributes
)

"Drag, open once, then preview Markdown from Finder.".draw(
    in: NSRect(x: 0, y: 388, width: canvasSize.width, height: 22),
    withAttributes: subtitleAttributes
)

let arrow = NSBezierPath()
arrow.move(to: NSPoint(x: 305, y: 272))
arrow.line(to: NSPoint(x: 455, y: 272))
arrow.move(to: NSPoint(x: 438, y: 287))
arrow.line(to: NSPoint(x: 458, y: 272))
arrow.line(to: NSPoint(x: 438, y: 257))
arrow.lineWidth = 2.5
NSColor.separatorColor.withAlphaComponent(0.85).setStroke()
arrow.stroke()

let steps = [
    ("1", "Drag QuillLook to Applications"),
    ("2", "Open QuillLook once"),
    ("3", "Select a Markdown file and press Space")
]

for (index, step) in steps.enumerated() {
    let y = 146 - CGFloat(index * 34)
    let badgeRect = NSRect(x: 170, y: y - 1, width: 22, height: 22)
    let badgePath = NSBezierPath(ovalIn: badgeRect)
    NSColor.controlAccentColor.withAlphaComponent(0.15).setFill()
    badgePath.fill()
    NSColor.controlAccentColor.withAlphaComponent(0.65).setStroke()
    badgePath.lineWidth = 1
    badgePath.stroke()

    let numberStyle = NSMutableParagraphStyle()
    numberStyle.alignment = .center
    let numberAttributes: [NSAttributedString.Key: Any] = [
        .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
        .foregroundColor: NSColor.controlAccentColor,
        .paragraphStyle: numberStyle
    ]
    step.0.draw(in: NSRect(x: badgeRect.minX, y: badgeRect.minY + 3, width: badgeRect.width, height: 16), withAttributes: numberAttributes)
    step.1.draw(in: NSRect(x: 204, y: y, width: 400, height: 22), withAttributes: stepAttributes)
}

"Need to remove it later? Open Uninstall QuillLook from this disk image.".draw(
    in: NSRect(x: 0, y: 28, width: canvasSize.width, height: 18),
    withAttributes: helperAttributes
)

image.unlockFocus()

guard
    let tiffData = image.tiffRepresentation,
    let bitmap = NSBitmapImageRep(data: tiffData),
    let pngData = bitmap.representation(using: .png, properties: [:])
else {
    fputs("Failed to render DMG background.\n", stderr)
    exit(1)
}

do {
    try FileManager.default.createDirectory(
        at: outputURL.deletingLastPathComponent(),
        withIntermediateDirectories: true
    )
    try pngData.write(to: outputURL, options: .atomic)
} catch {
    fputs("Failed to write DMG background: \(error)\n", stderr)
    exit(1)
}
