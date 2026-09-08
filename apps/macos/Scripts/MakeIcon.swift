import CoreGraphics
import Foundation
import ImageIO
import UniformTypeIdentifiers

func iconError(_ message: String) -> NSError {
    NSError(domain: "GirafonIcon", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
}

guard (3...4).contains(CommandLine.arguments.count) else {
    throw iconError("Usage: make-icon <output.iconset> <source.png> [output.ico]")
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

func resizedImage(_ pixels: Int, inset: CGFloat = 0) throws -> CGImage {
    if pixels == image.width && inset == 0 { return image }
    guard let context = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8,
                                  bytesPerRow: 0, space: colorSpace,
                                  bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue) else {
        throw iconError("Could not create the \(pixels)-pixel icon canvas.")
    }
    context.interpolationQuality = .high
    let padding = CGFloat(pixels) * inset
    context.draw(image, in: CGRect(x: 0, y: 0, width: pixels, height: pixels)
        .insetBy(dx: padding, dy: padding))
    guard let resized = context.makeImage() else {
        throw iconError("Could not resize the shared icon to \(pixels) pixels.")
    }
    return resized
}

for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        // The shared PNG is a full-tile export; classic macOS icons need Dock margins.
        let resized = try resizedImage(pixels, inset: 96 / 1024)
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

// Windows supports PNG frames inside ICO files, including alpha transparency.
if CommandLine.arguments.count == 4 {
    let sizes = [16, 20, 24, 32, 40, 48, 64, 96, 128, 256]
    let frames: [Data] = try sizes.map { size in
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(data, UTType.png.identifier as CFString, 1, nil) else {
            throw iconError("Could not create the \(size)-pixel ICO frame.")
        }
        CGImageDestinationAddImage(destination, try resizedImage(size), nil)
        guard CGImageDestinationFinalize(destination) else {
            throw iconError("Could not encode the \(size)-pixel ICO frame.")
        }
        return data as Data
    }
    var ico = Data()
    func appendInteger<T: FixedWidthInteger>(_ value: T) {
        var littleEndian = value.littleEndian
        withUnsafeBytes(of: &littleEndian) { ico.append(contentsOf: $0) }
    }
    appendInteger(UInt16(0))
    appendInteger(UInt16(1))
    appendInteger(UInt16(sizes.count))
    var offset = 6 + 16 * sizes.count
    for (size, frame) in zip(sizes, frames) {
        let dimension = UInt8(size == 256 ? 0 : size)
        ico.append(contentsOf: [dimension, dimension, 0, 0])
        appendInteger(UInt16(1))
        appendInteger(UInt16(32))
        appendInteger(UInt32(frame.count))
        appendInteger(UInt32(offset))
        offset += frame.count
    }
    for frame in frames { ico.append(frame) }
    try ico.write(to: URL(fileURLWithPath: CommandLine.arguments[3]), options: .atomic)
}
