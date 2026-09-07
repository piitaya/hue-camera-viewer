import CoreGraphics
import CoreImage
import Foundation
import ImageIO

private struct Pixel: Equatable, CustomStringConvertible {
    let r: UInt8
    let g: UInt8
    let b: UInt8
    let a: UInt8 = 255

    var bytes: [UInt8] { [r, g, b, a] }
    var description: String { "(\(r),\(g),\(b))" }
}

private enum TestFailure: Error, CustomStringConvertible {
    case assertion(String)
    var description: String {
        switch self { case .assertion(let message): return message }
    }
}

private func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() { throw TestFailure.assertion(message) }
}

private let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!
private let bitmapInfo = CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue

private func makeImage(_ rows: [[Pixel]]) -> CGImage {
    let bytes = rows.flatMap { $0.flatMap(\.bytes) }
    let provider = CGDataProvider(data: Data(bytes) as CFData)!
    return CGImage(
        width: rows[0].count, height: rows.count,
        bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: rows[0].count * 4,
        space: sRGB, bitmapInfo: CGBitmapInfo(rawValue: bitmapInfo),
        provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent
    )!
}

private func readPixels(_ image: CGImage) -> [[Pixel]] {
    var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
    bytes.withUnsafeMutableBytes { buffer in
        let context = CGContext(
            data: buffer.baseAddress,
            width: image.width, height: image.height,
            bitsPerComponent: 8, bytesPerRow: image.width * 4,
            space: sRGB, bitmapInfo: bitmapInfo
        )!
        context.setBlendMode(.copy)
        context.interpolationQuality = .none
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    }
    return (0..<image.height).map { row in
        (0..<image.width).map { column in
            let start = (row * image.width + column) * 4
            return Pixel(r: bytes[start], g: bytes[start + 1], b: bytes[start + 2])
        }
    }
}

@main
private struct ImagePipelineTests {
    static func main() throws {
        // A different color at every coordinate catches axis swaps and wrong rotation direction.
        let red = Pixel(r: 255, g: 0, b: 0)
        let green = Pixel(r: 0, g: 255, b: 0)
        let blue = Pixel(r: 0, g: 0, b: 255)
        let yellow = Pixel(r: 255, g: 255, b: 0)
        let magenta = Pixel(r: 255, g: 0, b: 255)
        let cyan = Pixel(r: 0, g: 255, b: 255)
        let input = [[red, green, blue], [yellow, magenta, cyan]]
        // Explicit clockwise reference matrices use displayed rows, from top to bottom.
        let rotations = [
            input,
            [[yellow, red], [magenta, green], [cyan, blue]],
            [[cyan, magenta, yellow], [blue, green, red]],
            [[blue, cyan], [green, magenta], [red, yellow]],
        ]
        let source = CIImage(cgImage: makeImage(input))
        let processor = ImageProcessor()

        for turns in 0..<4 {
            let orientation = ImageOrientation(quarterTurns: turns)
            let expected = rotations[turns]
            let output = try processor.render(source, orientation: orientation)
            try expect(output.width == expected[0].count, "Wrong width for \(orientation)")
            try expect(output.height == expected.count, "Wrong height for \(orientation)")
            let actual = readPixels(output)
            try expect(actual == expected, "Wrong pixels for \(orientation): \(actual), expected \(expected)")

            let shifted = source.transformed(by: CGAffineTransform(translationX: -19, y: 37))
            let normalized = try processor.render(shifted, orientation: orientation)
            try expect(readPixels(normalized) == expected, "Nonzero extent changed \(orientation)")
        }

        for turns in [-9, -4, -1, 4, 5, 10] {
            let output = try processor.render(source, orientation: ImageOrientation(quarterTurns: turns))
            try expect(readPixels(output) == rotations[((turns % 4) + 4) % 4], "Unbounded rotation failed: \(turns)")
        }

        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("hue-image-tests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: folder) }
        let oriented = try processor.render(source, orientation: ImageOrientation(quarterTurns: 1))
        let expectedSaved = readPixels(oriented)
        let fixedDate = Date(timeIntervalSince1970: 1_800_000_000.123)
        var savedURLs = Set<URL>()
        for _ in 0..<24 {
            let url = try processor.writePNG(oriented, to: folder, now: fixedDate)
            try expect(savedURLs.insert(url).inserted, "Two rapid captures used the same filename")
            try expect(url.pathExtension == "png", "Wrong file extension")
            let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil)!
            try expect(CGImageSourceGetType(imageSource) as String? == "public.png", "File is not PNG")
            let decoded = CGImageSourceCreateImageAtIndex(imageSource, 0, nil)!
            try expect(decoded.width == 2 && decoded.height == 3, "PNG dimensions changed")
            try expect(readPixels(decoded) == expectedSaved, "PNG roundtrip changed image orientation or pixels")
        }
        let files = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
        try expect(files.count == 24, "Captures were overwritten or temporary files were left behind")
        for url in savedURLs {
            try expect(FileManager.default.fileExists(atPath: url.path), "An earlier capture was removed")
        }

        do {
            _ = try processor.render(CIImage.empty(), orientation: ImageOrientation())
            throw TestFailure.assertion("An empty image should fail")
        } catch ImagePipelineError.invalidImageExtent {
            // Expected: invalid camera frames must not reach Core Image rendering.
        }
        print("PASS: 4 clockwise rotations, shifted extents, rotation wrapping, 24 unique atomic PNG saves and roundtrips, invalid extent.")
    }
}
