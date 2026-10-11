// Draws the 1280×640 GitHub social preview (the image shown when the repo link is shared).
// Usage: swift scripts/make-social-preview.swift <AppIcon-1024.png> <output.png>
import AppKit

let args = CommandLine.arguments
let iconPath = args.count > 1 ? args[1] : "Resources/AppIcon-1024.png"
let output = args.count > 2 ? args[2] : "docs/social-preview.png"

let width = 1280, height = 640
let space = CGColorSpace(name: CGColorSpace.sRGB)!
let ctx = CGContext(
    data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
    space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
)!

func color(_ hex: UInt32, _ alpha: CGFloat = 1) -> CGColor {
    CGColor(
        srgbRed: CGFloat((hex >> 16) & 0xFF) / 255,
        green: CGFloat((hex >> 8) & 0xFF) / 255,
        blue: CGFloat(hex & 0xFF) / 255,
        alpha: alpha
    )
}

// Dark navy → indigo background so the colourful icon stands out.
let background = CGGradient(
    colorsSpace: space, colors: [color(0x0E1033), color(0x221A5E)] as CFArray, locations: [0, 1]
)!
ctx.drawLinearGradient(background, start: .zero, end: CGPoint(x: width, y: height), options: [])

// Soft glow behind the icon.
let glow = CGGradient(
    colorsSpace: space, colors: [color(0x6A5CFF, 0.55), color(0x6A5CFF, 0)] as CFArray, locations: [0, 1]
)!
let iconCenter = CGPoint(x: 300, y: 320)
ctx.drawRadialGradient(glow, startCenter: iconCenter, startRadius: 0, endCenter: iconCenter, endRadius: 300, options: [])

// App icon.
let iconImage = NSImage(contentsOfFile: iconPath)!
var iconRect = CGRect(x: iconCenter.x - 190, y: iconCenter.y - 190, width: 380, height: 380)
ctx.draw(iconImage.cgImage(forProposedRect: &iconRect, context: nil, hints: nil)!, in: iconRect)

// Text (drawn through AppKit so we get system fonts).
NSGraphicsContext.current = NSGraphicsContext(cgContext: ctx, flipped: false)

func draw(_ text: String, at point: CGPoint, size: CGFloat, weight: NSFont.Weight, alpha: CGFloat, monospaced: Bool = false) {
    let font = monospaced
        ? NSFont.monospacedSystemFont(ofSize: size, weight: weight)
        : NSFont.systemFont(ofSize: size, weight: weight)
    let attributes: [NSAttributedString.Key: Any] = [
        .font: font,
        .foregroundColor: NSColor.white.withAlphaComponent(alpha),
    ]
    NSAttributedString(string: text, attributes: attributes).draw(at: point)
}

let textX: CGFloat = 540
draw("Volume Mixer", at: CGPoint(x: textX, y: 370), size: 88, weight: .bold, alpha: 1)
draw("Per-app volume control for macOS", at: CGPoint(x: textX, y: 315), size: 38, weight: .medium, alpha: 0.92)
draw("Free  ·  Open source  ·  Native Swift", at: CGPoint(x: textX, y: 255), size: 28, weight: .regular, alpha: 0.7)
draw("github.com/dracuthang2000/Volume-mixer", at: CGPoint(x: textX, y: 150), size: 24, weight: .regular, alpha: 0.6, monospaced: true)

NSGraphicsContext.current = nil

let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
try! rep.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: output))
print("Wrote \(output)")
