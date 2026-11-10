// Draws Keep Working's icons from the character's own head: the 12 x 4 cell body with its two eyes cut out.
// Cells are 1.7x taller than wide, like the widget's character.
//   swiftc Tools/make-icons.swift -o build/make-icons && build/make-icons App/Resources
// Writes AppIcon.icns (via iconutil) and MenuIconTemplate.png / @2x (black, eyes clear; macOS tints it).
import AppKit

let clay = NSColor(srgbRed: 0.851, green: 0.467, blue: 0.341, alpha: 1)
let ink = NSColor(srgbRed: 0.105, green: 0.094, blue: 0.086, alpha: 1)

/// The head in a rect: body, then the eyes punched out. `rect` is the body's box.
/// `eyes` nil cuts them clear (menu-bar template); a colour paints them (the app icon's tile shows through).
func drawHead(in ctx: CGContext, rect: CGRect, color: NSColor, eyes: NSColor? = nil) {
    let cell = rect.width / 12, row = rect.height / 4
    ctx.setFillColor(color.cgColor)
    ctx.fill(rect)
    if let eyes { ctx.setFillColor(eyes.cgColor) } else { ctx.setBlendMode(.clear) }
    // Eyes: one cell wide, one row tall, second row from the top, cells 2 and 9 (as in the sprite).
    for c in [2.0, 9.0] {
        ctx.fill(CGRect(x: rect.minX + c * cell, y: rect.maxY - 2 * row, width: cell, height: row))
    }
    ctx.setBlendMode(.normal)
}

func png(size: Int, _ draw: (CGContext, CGFloat) -> Void) -> Data {
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: size, pixelsHigh: size, bitsPerSample: 8,
                               samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                               bytesPerRow: 0, bitsPerPixel: 0)!
    let g = NSGraphicsContext(bitmapImageRep: rep)!
    draw(g.cgContext, CGFloat(size))
    g.flushGraphics()
    return rep.representation(using: .png, properties: [:])!
}

/// App icon: Apple's grid (an 824 rounded square inside 1024), dark ink, the clay head centred a touch high.
func appIcon(_ s: CGFloat) -> (CGContext, CGFloat) -> Void {
    return { ctx, s in
        let k = s / 1024
        let tile = CGRect(x: 100 * k, y: 100 * k, width: 824 * k, height: 824 * k)
        ctx.addPath(CGPath(roundedRect: tile, cornerWidth: 185 * k, cornerHeight: 185 * k, transform: nil))
        ctx.setFillColor(ink.cgColor)
        ctx.fillPath()
        let w = 560 * k, h = w / 12 * 4 * 1.7
        let head = CGRect(x: (s - w) / 2, y: (s - h) / 2 + 20 * k, width: w, height: h)
        drawHead(in: ctx, rect: head, color: clay, eyes: ink)
    }
}

/// Menu bar: an 18 pt template, head 16 pt wide, black, eyes clear.
func menuIcon(_ ctx: CGContext, _ s: CGFloat) {
    let k = s / 18
    let w = 16 * k, h = (w / 12 * 4 * 1.7).rounded()
    drawHead(in: ctx, rect: CGRect(x: (s - w) / 2, y: ((s - h) / 2).rounded(), width: w, height: h), color: .black)
}

let out = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "."
let fm = FileManager.default
try? fm.createDirectory(atPath: out, withIntermediateDirectories: true)
let set = NSTemporaryDirectory() + "KeepWorking.iconset"
try? fm.removeItem(atPath: set)
try! fm.createDirectory(atPath: set, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let px = base * scale
        let name = scale == 1 ? "icon_\(base)x\(base).png" : "icon_\(base)x\(base)@2x.png"
        try! png(size: px, appIcon(CGFloat(px))).write(to: URL(fileURLWithPath: "\(set)/\(name)"))
    }
}
let task = Process()
task.executableURL = URL(fileURLWithPath: "/usr/bin/iconutil")
task.arguments = ["-c", "icns", set, "-o", "\(out)/AppIcon.icns"]
try! task.run(); task.waitUntilExit()
try! png(size: 1024, appIcon(1024)).write(to: URL(fileURLWithPath: "\(out)/AppIcon-1024.png"))
try! png(size: 18, menuIcon).write(to: URL(fileURLWithPath: "\(out)/MenuIconTemplate.png"))
try! png(size: 36, menuIcon).write(to: URL(fileURLWithPath: "\(out)/MenuIconTemplate@2x.png"))
print("wrote icons to \(out)")
