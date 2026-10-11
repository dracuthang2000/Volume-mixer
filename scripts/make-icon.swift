// Draws the 1024×1024 app icon: a rounded square with three mixer sliders.
// Usage: swift scripts/make-icon.swift <output.png>
import AppKit

let size: CGFloat = 1024
let output = CommandLine.arguments.count > 1 ? CommandLine.arguments[1] : "icon_1024.png"

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

let space = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(
    data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8, bytesPerRow: 0,
    space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
)!

// macOS icon grid: 824 pt body centred on a 1024 canvas, ~185 pt corner radius.
let body = CGRect(x: 100, y: 100, width: 824, height: 824)
let bodyPath = CGPath(roundedRect: body, cornerWidth: 185, cornerHeight: 185, transform: nil)

// Drop shadow under the body.
ctx.saveGState()
ctx.setShadow(offset: CGSize(width: 0, height: -14), blur: 34, color: color(0x000000, 0.35))
ctx.addPath(bodyPath)
ctx.setFillColor(color(0x3B4FD8))
ctx.fillPath()
ctx.restoreGState()

// Background gradient (top blue → bottom violet).
ctx.saveGState()
ctx.addPath(bodyPath)
ctx.clip()
let background = CGGradient(
    colorsSpace: space,
    colors: [color(0x5B8CFF), color(0x5A55F0), color(0x8A3FE0)] as CFArray,
    locations: [0, 0.5, 1]
)!
ctx.drawLinearGradient(background, start: CGPoint(x: 0, y: body.maxY), end: CGPoint(x: 0, y: body.minY), options: [])

// Soft glossy highlight on the top half.
let highlight = CGGradient(
    colorsSpace: space,
    colors: [color(0xFFFFFF, 0.22), color(0xFFFFFF, 0)] as CFArray,
    locations: [0, 1]
)!
ctx.drawLinearGradient(highlight, start: CGPoint(x: 0, y: body.maxY), end: CGPoint(x: 0, y: body.midY), options: [])
ctx.restoreGState()

// Three sliders, like a mixing desk: (x position, knob level 0…1).
let sliders: [(x: CGFloat, level: CGFloat)] = [(352, 0.38), (512, 0.78), (672, 0.56)]
let trackBottom: CGFloat = 268
let trackTop: CGFloat = 756
let trackWidth: CGFloat = 40
let knobRadius: CGFloat = 62

for slider in sliders {
    let knobY = trackBottom + (trackTop - trackBottom) * slider.level

    // Empty track.
    let track = CGRect(x: slider.x - trackWidth / 2, y: trackBottom, width: trackWidth, height: trackTop - trackBottom)
    ctx.addPath(CGPath(roundedRect: track, cornerWidth: trackWidth / 2, cornerHeight: trackWidth / 2, transform: nil))
    ctx.setFillColor(color(0x1B1460, 0.35))
    ctx.fillPath()

    // Filled part (bottom → knob).
    let filled = CGRect(x: track.minX, y: trackBottom, width: trackWidth, height: knobY - trackBottom)
    ctx.addPath(CGPath(roundedRect: filled, cornerWidth: trackWidth / 2, cornerHeight: trackWidth / 2, transform: nil))
    ctx.setFillColor(color(0xFFFFFF, 0.92))
    ctx.fillPath()

    // Knob with shadow.
    let knob = CGRect(x: slider.x - knobRadius, y: knobY - knobRadius, width: knobRadius * 2, height: knobRadius * 2)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -8), blur: 18, color: color(0x140A50, 0.45))
    ctx.setFillColor(color(0xFFFFFF))
    ctx.fillEllipse(in: knob)
    ctx.restoreGState()

    // Knob grip line.
    ctx.setStrokeColor(color(0x5A55F0, 0.85))
    ctx.setLineWidth(12)
    ctx.setLineCap(.round)
    ctx.move(to: CGPoint(x: slider.x - 26, y: knobY))
    ctx.addLine(to: CGPoint(x: slider.x + 26, y: knobY))
    ctx.strokePath()
}

let image = ctx.makeImage()!
let rep = NSBitmapImageRep(cgImage: image)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
print("Wrote \(output)")
