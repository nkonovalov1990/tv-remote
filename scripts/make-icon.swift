// Generates TVRemote/Assets.xcassets/AppIcon.appiconset (all macOS sizes) from code.
// Run from the repo root: swift scripts/make-icon.swift
import AppKit

let dir = URL(fileURLWithPath: "TVRemote/Assets.xcassets/AppIcon.appiconset")
try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)

func draw(_ px: Int) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: px, pixelsHigh: px, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
    let cg = NSGraphicsContext.current!.cgContext
    let s = CGFloat(px) / 1024
    cg.scaleBy(x: s, y: s)
    // Flip to top-left origin so the numbers below read like a design spec.
    cg.translateBy(x: 0, y: 1024); cg.scaleBy(x: 1, y: -1)

    // Body: Apple's macOS grid — 824pt tile, 100pt margin, soft drop shadow.
    let body = CGPath(roundedRect: CGRect(x: 100, y: 100, width: 824, height: 824), cornerWidth: 185, cornerHeight: 185, transform: nil)
    cg.saveGState()
    cg.setShadow(offset: CGSize(width: 0, height: 12), blur: 28, color: NSColor.black.withAlphaComponent(0.3).cgColor)
    cg.addPath(body); cg.setFillColor(NSColor(red: 0.04, green: 0.37, blue: 0.84, alpha: 1).cgColor); cg.fillPath()
    cg.restoreGState()
    cg.saveGState()
    cg.addPath(body); cg.clip()
    let grad = CGGradient(colorsSpace: nil, colors: [NSColor(red: 0.20, green: 0.52, blue: 0.96, alpha: 1).cgColor,
                                                     NSColor(red: 0.03, green: 0.31, blue: 0.75, alpha: 1).cgColor] as CFArray, locations: [0, 1])!
    cg.drawLinearGradient(grad, start: CGPoint(x: 512, y: 100), end: CGPoint(x: 512, y: 924), options: [])
    cg.restoreGState()

    let white = NSColor.white.cgColor
    // TV: screen outline + stand.
    cg.setStrokeColor(white); cg.setLineWidth(44); cg.setLineCap(.round)
    cg.addPath(CGPath(roundedRect: CGRect(x: 222, y: 270, width: 580, height: 400), cornerWidth: 64, cornerHeight: 64, transform: nil))
    cg.strokePath()
    cg.move(to: CGPoint(x: 392, y: 770)); cg.addLine(to: CGPoint(x: 632, y: 770)); cg.strokePath()
    cg.move(to: CGPoint(x: 512, y: 692)); cg.addLine(to: CGPoint(x: 512, y: 770)); cg.strokePath()

    // Play/pause glyph centred in the screen.
    cg.setFillColor(white)
    cg.move(to: CGPoint(x: 391, y: 390)); cg.addLine(to: CGPoint(x: 391, y: 550)); cg.addLine(to: CGPoint(x: 511, y: 470)); cg.closePath(); cg.fillPath()
    cg.addPath(CGPath(roundedRect: CGRect(x: 543, y: 390, width: 32, height: 160), cornerWidth: 8, cornerHeight: 8, transform: nil))
    cg.addPath(CGPath(roundedRect: CGRect(x: 601, y: 390, width: 32, height: 160), cornerWidth: 8, cornerHeight: 8, transform: nil))
    cg.fillPath()

    NSGraphicsContext.current = nil
    return rep.representation(using: .png, properties: [:])!
}

var images: [String] = []
for pt in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let name = "icon_\(pt)x\(pt)\(scale == 2 ? "@2x" : "").png"
        try draw(pt * scale).write(to: dir.appendingPathComponent(name))
        images.append(#"{"idiom":"mac","size":"\#(pt)x\#(pt)","scale":"\#(scale)x","filename":"\#(name)"}"#)
    }
}
try #"{"images":[\#(images.joined(separator: ","))],"info":{"version":1,"author":"xcode"}}"#
    .write(to: dir.appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
try #"{"info":{"version":1,"author":"xcode"}}"#
    .write(to: dir.deletingLastPathComponent().appendingPathComponent("Contents.json"), atomically: true, encoding: .utf8)
print("wrote \(images.count) icons to \(dir.path)")
