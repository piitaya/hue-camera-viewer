import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

let iconDirectory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: iconDirectory, withIntermediateDirectories: true)
let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!
let deepGreen = CGColor(red: 0.08, green: 0.29, blue: 0.23, alpha: 1)
let green = CGColor(red: 0.22, green: 0.59, blue: 0.39, alpha: 1)
let lightGreen = CGColor(red: 0.37, green: 0.73, blue: 0.46, alpha: 1)
let ivory = CGColor(red: 0.97, green: 0.97, blue: 0.93, alpha: 1)

func fillRoundedRect(_ rect: CGRect, radius: CGFloat, color: CGColor, in context: CGContext) {
    context.setFillColor(color)
    context.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
    context.fillPath()
}

func gradientRoundedRect(_ rect: CGRect, radius: CGFloat, bottom: CGColor, top: CGColor, in context: CGContext) {
    context.saveGState()
    context.addPath(CGPath(roundedRect: rect, cornerWidth: radius, cornerHeight: radius, transform: nil))
    context.clip()
    let gradient = CGGradient(colorsSpace: colorSpace, colors: [bottom, top] as CFArray, locations: [0, 1])!
    context.drawLinearGradient(gradient, start: CGPoint(x: rect.midX, y: rect.minY),
                               end: CGPoint(x: rect.midX, y: rect.maxY), options: [])
    context.restoreGState()
}

func drawIcon(in context: CGContext) {
    // One large camera shape stays readable down to the Dock's small sizes.
    let tile = CGRect(x: 64, y: 64, width: 896, height: 896)
    context.setShadow(offset: CGSize(width: 0, height: -8), blur: 20,
                      color: CGColor(gray: 0, alpha: 0.14))
    fillRoundedRect(tile, radius: 200, color: ivory, in: context)
    context.setShadow(offset: .zero, blur: 0)
    gradientRoundedRect(tile, radius: 200,
                        bottom: CGColor(red: 0.92, green: 0.94, blue: 0.87, alpha: 1),
                        top: CGColor(red: 0.995, green: 0.995, blue: 0.97, alpha: 1), in: context)

    // The raised camera head contains a single broad lens, without a neck or tiny controls.
    let camera = CGRect(x: 216, y: 284, width: 592, height: 456)
    context.setShadow(offset: CGSize(width: 0, height: -13), blur: 20,
                      color: CGColor(red: 0.10, green: 0.25, blue: 0.15, alpha: 0.18))
    fillRoundedRect(camera, radius: 112, color: green, in: context)
    context.setShadow(offset: .zero, blur: 0)
    gradientRoundedRect(camera, radius: 112, bottom: green, top: lightGreen, in: context)

    let lensCenter = CGPoint(x: 512, y: 512)
    func disc(radius: CGFloat, color: CGColor) {
        context.setFillColor(color)
        context.fillEllipse(in: CGRect(x: lensCenter.x - radius, y: lensCenter.y - radius,
                                       width: radius * 2, height: radius * 2))
    }
    disc(radius: 171, color: CGColor(red: 0.98, green: 0.995, blue: 0.95, alpha: 1))
    disc(radius: 132, color: deepGreen)
    disc(radius: 93, color: CGColor(red: 0.07, green: 0.18, blue: 0.18, alpha: 1))

    // A restrained reflection makes the central circle read as optical glass.
    context.setFillColor(CGColor(red: 0.41, green: 0.77, blue: 0.65, alpha: 0.90))
    context.fillEllipse(in: CGRect(x: 449, y: 519, width: 72, height: 72))
    context.setFillColor(CGColor(red: 0.94, green: 1, blue: 0.97, alpha: 0.92))
    context.fillEllipse(in: CGRect(x: 459, y: 556, width: 24, height: 24))
}

for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let context = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8,
                                bytesPerRow: 0, space: colorSpace,
                                bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        context.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
        drawIcon(in: context)
        let suffix = scale == 2 ? "@2x" : ""
        let url = iconDirectory.appendingPathComponent("icon_\(size)x\(size)\(suffix).png")
        let destination = CGImageDestinationCreateWithURL(url as CFURL, UTType.png.identifier as CFString, 1, nil)!
        CGImageDestinationAddImage(destination, context.makeImage()!, nil)
        precondition(CGImageDestinationFinalize(destination))
    }
}
