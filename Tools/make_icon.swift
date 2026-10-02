// Draws the 1024×1024 app icon: the children's purple→orange gradient, a white tick, and a gold £ coin.
// Run: swift make_icon.swift <output.png>
import AppKit

let size: CGFloat = 1024
let output = CommandLine.arguments.dropFirst().first ?? "AppIcon.png"

func colour(_ hex: UInt32, alpha: CGFloat = 1) -> NSColor {
    NSColor(srgbRed: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255, blue: CGFloat(hex & 0xFF) / 255, alpha: alpha)
}

let rep = NSBitmapImageRep(
    bitmapDataPlanes: nil, pixelsWide: Int(size), pixelsHigh: Int(size), bitsPerSample: 8, samplesPerPixel: 4,
    hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
)!
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: rep)
let context = NSGraphicsContext.current!.cgContext

// Background: full bleed (iOS applies the rounded mask), purple top-left to orange bottom-right.
let gradient = NSGradient(colors: [colour(0x6C4DFF), colour(0xB44FD8), colour(0xFF8A3D)], atLocations: [0, 0.55, 1], colorSpace: .sRGB)!
gradient.draw(in: NSRect(x: 0, y: 0, width: size, height: size), angle: -45)

// Soft light in the top-left for depth.
let glow = NSGradient(colors: [colour(0xFFFFFF, alpha: 0.22), colour(0xFFFFFF, alpha: 0)])!
glow.draw(fromCenter: NSPoint(x: 300, y: 760), radius: 0, toCenter: NSPoint(x: 300, y: 760), radius: 620, options: [])

// The tick, slightly up and left so the coin can sit bottom-right.
let tick = NSBezierPath()
tick.move(to: NSPoint(x: 230, y: 560))
tick.line(to: NSPoint(x: 420, y: 370))
tick.line(to: NSPoint(x: 790, y: 740))
tick.lineWidth = 128
tick.lineCapStyle = .round
tick.lineJoinStyle = .round
context.saveGState()
context.setShadow(offset: CGSize(width: 0, height: -14), blur: 30, color: colour(0x2A0D5E, alpha: 0.35).cgColor)
colour(0xFFFFFF).setStroke()
tick.stroke()
context.restoreGState()

// Gold coin with a £.
let coinCentre = NSPoint(x: 735, y: 265)
let coinRadius: CGFloat = 175
context.saveGState()
context.setShadow(offset: CGSize(width: 0, height: -12), blur: 28, color: colour(0x3D1A00, alpha: 0.35).cgColor)
let coin = NSBezierPath(ovalIn: NSRect(x: coinCentre.x - coinRadius, y: coinCentre.y - coinRadius, width: coinRadius * 2, height: coinRadius * 2))
NSGradient(colors: [colour(0xFFE07A), colour(0xF5B301)])!.draw(in: coin, angle: -90)
context.restoreGState()
colour(0xFFFFFF, alpha: 0.9).setStroke()
coin.lineWidth = 16
coin.stroke()
let inner = NSBezierPath(ovalIn: NSRect(x: coinCentre.x - coinRadius + 34, y: coinCentre.y - coinRadius + 34, width: (coinRadius - 34) * 2, height: (coinRadius - 34) * 2))
colour(0xC98A00, alpha: 0.45).setStroke()
inner.lineWidth = 6
inner.stroke()

let pound = NSAttributedString(string: "£", attributes: [
    .font: NSFont.systemFont(ofSize: 230, weight: .heavy),
    .foregroundColor: colour(0x8A5300),
])
let poundSize = pound.size()
pound.draw(at: NSPoint(x: coinCentre.x - poundSize.width / 2, y: coinCentre.y - poundSize.height / 2 + 6))

NSGraphicsContext.restoreGraphicsState()

// iOS icons must be opaque: redraw into an RGB context with no alpha channel, then save as PNG.
let flat = CGContext(
    data: nil, width: Int(size), height: Int(size), bitsPerComponent: 8, bytesPerRow: 0,
    space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.noneSkipLast.rawValue
)!
flat.draw(rep.cgImage!, in: CGRect(x: 0, y: 0, width: size, height: size))
let destination = CGImageDestinationCreateWithURL(URL(fileURLWithPath: output) as CFURL, "public.png" as CFString, 1, nil)!
CGImageDestinationAddImage(destination, flat.makeImage()!, nil)
precondition(CGImageDestinationFinalize(destination), "Couldn't write \(output)")
print("wrote \(output)")
