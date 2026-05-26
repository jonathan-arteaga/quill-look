import AppKit
import Foundation

let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
let resources = root.appendingPathComponent("QuillLook/Resources", isDirectory: true)
let iconset = resources.appendingPathComponent("AppIcon.iconset", isDirectory: true)
let icns = resources.appendingPathComponent("AppIcon.icns")

try? FileManager.default.removeItem(at: iconset)
try? FileManager.default.removeItem(at: icns)
try FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)

struct IconRenderer {
    let size: CGFloat

    func draw() -> NSImage {
        let image = NSImage(size: NSSize(width: size, height: size))
        image.lockFocus()
        defer { image.unlockFocus() }

        let rect = CGRect(x: 0, y: 0, width: size, height: size)
        NSGraphicsContext.current?.cgContext.setShouldAntialias(true)

        let bg = NSBezierPath(roundedRect: rect.insetBy(dx: size * 0.055, dy: size * 0.055), xRadius: size * 0.22, yRadius: size * 0.22)
        NSColor(calibratedRed: 0.94, green: 0.975, blue: 1.0, alpha: 1).setFill()
        bg.fill()

        let accent = NSBezierPath(roundedRect: rect.insetBy(dx: size * 0.16, dy: size * 0.16), xRadius: size * 0.16, yRadius: size * 0.16)
        NSColor(calibratedRed: 0.12, green: 0.47, blue: 0.95, alpha: 0.11).setFill()
        accent.fill()

        let pageRect = CGRect(x: size * 0.29, y: size * 0.20, width: size * 0.42, height: size * 0.60)
        let page = NSBezierPath(roundedRect: pageRect, xRadius: size * 0.045, yRadius: size * 0.045)
        NSColor.white.setFill()
        page.fill()
        NSColor(calibratedWhite: 0.86, alpha: 1).setStroke()
        page.lineWidth = max(1, size * 0.014)
        page.stroke()

        let fold = NSBezierPath()
        fold.move(to: CGPoint(x: pageRect.maxX - size * 0.13, y: pageRect.maxY))
        fold.line(to: CGPoint(x: pageRect.maxX, y: pageRect.maxY - size * 0.13))
        fold.line(to: CGPoint(x: pageRect.maxX - size * 0.13, y: pageRect.maxY - size * 0.13))
        fold.close()
        NSColor(calibratedRed: 0.90, green: 0.95, blue: 1.0, alpha: 1).setFill()
        fold.fill()

        let ink = NSColor(calibratedRed: 0.08, green: 0.12, blue: 0.18, alpha: 1)
        ink.setStroke()
        for offset in [0.0, 0.07, 0.14] {
            let y = pageRect.maxY - size * (0.23 + offset)
            let line = NSBezierPath()
            line.move(to: CGPoint(x: pageRect.minX + size * 0.09, y: y))
            line.line(to: CGPoint(x: pageRect.maxX - size * 0.10, y: y))
            line.lineCapStyle = .round
            line.lineWidth = max(1.5, size * 0.026)
            line.stroke()
        }

        let lensRect = CGRect(x: size * 0.40, y: size * 0.28, width: size * 0.31, height: size * 0.31)
        let lens = NSBezierPath(ovalIn: lensRect)
        NSColor(calibratedWhite: 1, alpha: 0.86).setFill()
        lens.fill()
        ink.setStroke()
        lens.lineWidth = max(2, size * 0.036)
        lens.stroke()

        let handle = NSBezierPath()
        handle.move(to: CGPoint(x: lensRect.maxX - size * 0.035, y: lensRect.minY + size * 0.035))
        handle.line(to: CGPoint(x: size * 0.76, y: size * 0.19))
        handle.lineCapStyle = .round
        handle.lineWidth = max(2.5, size * 0.045)
        handle.stroke()

        NSColor(calibratedRed: 0.08, green: 0.47, blue: 0.92, alpha: 1).setStroke()
        let quill = NSBezierPath()
        quill.move(to: CGPoint(x: size * 0.31, y: size * 0.23))
        quill.curve(to: CGPoint(x: size * 0.58, y: size * 0.69), controlPoint1: CGPoint(x: size * 0.39, y: size * 0.45), controlPoint2: CGPoint(x: size * 0.44, y: size * 0.61))
        quill.lineCapStyle = .round
        quill.lineWidth = max(2.5, size * 0.032)
        quill.stroke()

        return image
    }
}

let outputs: [(String, CGFloat)] = [
    ("icon_16x16.png", 16),
    ("icon_16x16@2x.png", 32),
    ("icon_32x32.png", 32),
    ("icon_32x32@2x.png", 64),
    ("icon_128x128.png", 128),
    ("icon_128x128@2x.png", 256),
    ("icon_256x256.png", 256),
    ("icon_256x256@2x.png", 512),
    ("icon_512x512.png", 512),
    ("icon_512x512@2x.png", 1024)
]

for (name, size) in outputs {
    let image = IconRenderer(size: size).draw()
    guard let tiff = image.tiffRepresentation,
          let bitmap = NSBitmapImageRep(data: tiff),
          let data = bitmap.representation(using: .png, properties: [:]) else {
        fatalError("Could not render \(name)")
    }
    try data.write(to: iconset.appendingPathComponent(name))
}

let process = Process()
process.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
process.arguments = ["-c", "icns", iconset.path, "-o", icns.path]
try process.run()
process.waitUntilExit()
guard process.terminationStatus == 0 else {
    fatalError("iconutil failed")
}

try? FileManager.default.removeItem(at: iconset)
print("Generated \(icns.path)")
