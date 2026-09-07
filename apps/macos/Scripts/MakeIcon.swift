import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

func iconError(_ message: String) -> NSError {
    NSError(domain: "HueIcon", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
}

guard CommandLine.arguments.count == 3 else {
    throw iconError("Usage: make-icon <output.iconset> <source.png>")
}
let iconDirectory = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
let sourceURL = URL(fileURLWithPath: CommandLine.arguments[2])
guard let source = CGImageSourceCreateWithURL(sourceURL as CFURL, nil),
      let image = CGImageSourceCreateImageAtIndex(source, 0, nil),
      image.width == image.height, image.width >= 1024 else {
    throw iconError("The shared icon must be a square image of at least 1024 pixels.")
}
try FileManager.default.createDirectory(at: iconDirectory, withIntermediateDirectories: true)
let colorSpace = CGColorSpace(name: CGColorSpace.sRGB)!

for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let resized: CGImage
        if pixels == image.width {
            resized = image
        } else {
            guard let context = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8,
                                          bytesPerRow: 0, space: colorSpace,
                                          bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
                throw iconError("Could not create the \(pixels)-pixel icon canvas.")
            }
            context.interpolationQuality = .high
            context.draw(image, in: CGRect(x: 0, y: 0, width: pixels, height: pixels))
            guard let result = context.makeImage() else {
                throw iconError("Could not resize the shared icon to \(pixels) pixels.")
            }
            resized = result
        }
        let suffix = scale == 2 ? "@2x" : ""
        let url = iconDirectory.appendingPathComponent("icon_\(size)x\(size)\(suffix).png")
        guard let destination = CGImageDestinationCreateWithURL(url as CFURL,
                                                               UTType.png.identifier as CFString, 1, nil) else {
            throw iconError("Could not create \(url.lastPathComponent).")
        }
        CGImageDestinationAddImage(destination, resized, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw iconError("Could not write \(url.lastPathComponent).")
        }
    }
}
