import AppKit
import CoreGraphics
import ImageIO
import UniformTypeIdentifiers

// The Finder window uses 660 × 420 points; emit 1× and 2× representations.
let output = URL(fileURLWithPath: CommandLine.arguments[1])
let scale = Int(CommandLine.arguments[2])!
precondition(scale == 1 || scale == 2)
let size = CGSize(width: 660, height: 420)
let context = CGContext(data: nil, width: 660 * scale, height: 420 * scale, bitsPerComponent: 8,
                        bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB)!,
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
context.scaleBy(x: CGFloat(scale), y: CGFloat(scale))
context.translateBy(x: 0, y: size.height)
context.scaleBy(x: 1, y: -1)
let graphics = NSGraphicsContext(cgContext: context, flipped: true)
NSGraphicsContext.saveGraphicsState()
NSGraphicsContext.current = graphics

let ink = NSColor(srgbRed: 41 / 255, green: 37 / 255, blue: 33 / 255, alpha: 1)
let secondary = NSColor(srgbRed: 0.43, green: 0.37, blue: 0.31, alpha: 1)
let paper = NSColor(srgbRed: 1, green: 248 / 255, blue: 235 / 255, alpha: 1)
paper.setFill()
NSBezierPath(rect: CGRect(origin: .zero, size: size)).fill()

func text(_ string: String, top: CGFloat, size: CGFloat, weight: NSFont.Weight, color: NSColor) {
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    (string as NSString).draw(in: CGRect(x: 32, y: top, width: 596, height: 48), withAttributes: [
        .font: NSFont.systemFont(ofSize: size, weight: weight),
        .foregroundColor: color,
        .paragraphStyle: paragraph
    ])
}

text("Install Hue Camera Viewer", top: 44, size: 30, weight: .semibold, color: ink)
text("Drag Hue to Applications.", top: 89, size: 15, weight: .regular, color: secondary)

for center in [CGFloat(180), CGFloat(480)] {
    NSColor(srgbRed: 245 / 255, green: 182 / 255, blue: 49 / 255, alpha: 0.12).setFill()
    NSBezierPath(roundedRect: CGRect(x: center - 78, y: 149, width: 156, height: 158),
                 xRadius: 34, yRadius: 34).fill()
}

// A single generous arrow connects the real draggable Finder icons.
NSColor(srgbRed: 201 / 255, green: 93 / 255, blue: 53 / 255, alpha: 1).setStroke()
let arrow = NSBezierPath()
arrow.lineWidth = 3.5
arrow.lineCapStyle = .round
arrow.lineJoinStyle = .round
arrow.move(to: CGPoint(x: 302, y: 224))
arrow.line(to: CGPoint(x: 357, y: 224))
arrow.move(to: CGPoint(x: 345, y: 212))
arrow.line(to: CGPoint(x: 357, y: 224))
arrow.line(to: CGPoint(x: 345, y: 236))
arrow.stroke()

text("Then open Hue from Applications.", top: 366, size: 12,
     weight: .regular, color: secondary)
NSGraphicsContext.restoreGraphicsState()

let image = context.makeImage()!
let destination = CGImageDestinationCreateWithURL(output as CFURL, UTType.png.identifier as CFString, 1, nil)!
CGImageDestinationAddImage(destination, image, [kCGImagePropertyDPIWidth: 72 * scale,
                                               kCGImagePropertyDPIHeight: 72 * scale] as CFDictionary)
precondition(CGImageDestinationFinalize(destination))
