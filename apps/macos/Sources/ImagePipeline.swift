import CoreGraphics
import CoreImage
import Darwin
import Foundation
import ImageIO
import UniformTypeIdentifiers

/// Rotations are clockwise, in steps of 90 degrees.
struct ImageOrientation: Equatable, Codable {
    var quarterTurns: Int = 0
}

enum ImagePipelineError: LocalizedError {
    case invalidImageExtent
    case renderingFailed
    case pngEncodingFailed

    var errorDescription: String? {
        switch self {
        case .invalidImageExtent:
            return NSLocalizedString("The camera image has invalid dimensions.", comment: "Image processing error")
        case .renderingFailed:
            return NSLocalizedString("The camera image could not be prepared.", comment: "Image processing error")
        case .pngEncodingFailed:
            return NSLocalizedString("The PNG capture could not be created.", comment: "Image processing error")
        }
    }
}

/// Keep one processor on the camera's frame queue to reuse its rendering context.
final class ImageProcessor {
    private let colorSpace: CGColorSpace
    private let context: CIContext

    init() {
        let sRGB = CGColorSpace(name: CGColorSpace.sRGB)!
        colorSpace = sRGB
        context = CIContext(options: [
            .workingColorSpace: sRGB,
            .outputColorSpace: sRGB,
        ])
    }

    func render(_ image: CIImage, orientation: ImageOrientation) throws -> CGImage {
        let extent = image.extent
        guard !extent.isNull, !extent.isInfinite,
              extent.minX.isFinite, extent.minY.isFinite,
              extent.width.isFinite, extent.height.isFinite,
              extent.width > 0, extent.height > 0 else {
            throw ImagePipelineError.invalidImageExtent
        }

        var result = normalized(image)
        // Exact matrices avoid interpolation or an extra pixel caused by sin/cos rounding.
        let turns = ((orientation.quarterTurns % 4) + 4) % 4
        switch turns {
        case 1:
            result = result.transformed(by: CGAffineTransform(a: 0, b: -1, c: 1, d: 0, tx: 0, ty: 0))
        case 2:
            result = result.transformed(by: CGAffineTransform(a: -1, b: 0, c: 0, d: -1, tx: 0, ty: 0))
        case 3:
            result = result.transformed(by: CGAffineTransform(a: 0, b: 1, c: -1, d: 0, tx: 0, ty: 0))
        default:
            break
        }
        result = normalized(result)

        guard let rendered = context.createCGImage(
            result,
            from: result.extent.integral,
            format: .RGBA8,
            colorSpace: colorSpace
        ) else {
            throw ImagePipelineError.renderingFailed
        }
        return rendered
    }

    /// Writes a complete PNG and publishes it atomically without replacing an existing file.
    func writePNG(_ image: CGImage, to directory: URL, now: Date = Date()) throws -> URL {
        let data = NSMutableData()
        guard let destination = CGImageDestinationCreateWithData(
            data, UTType.png.identifier as CFString, 1, nil
        ) else {
            throw ImagePipelineError.pngEncodingFailed
        }
        CGImageDestinationAddImage(destination, image, nil)
        guard CGImageDestinationFinalize(destination) else {
            throw ImagePipelineError.pngEncodingFailed
        }

        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.dateFormat = "yyyy-MM-dd_HH-mm-ss-SSS"
        let timestamp = formatter.string(from: now)

        // The temporary file shares the destination's filesystem, so rename is atomic.
        let temporaryURL = directory.appendingPathComponent(".hue-\(UUID().uuidString).tmp")
        try (data as Data).write(to: temporaryURL, options: .withoutOverwriting)
        defer { try? FileManager.default.removeItem(at: temporaryURL) }

        while true {
            let name = "Capture_\(timestamp)_\(UUID().uuidString).png"
            let outputURL = directory.appendingPathComponent(name)
            let status = temporaryURL.withUnsafeFileSystemRepresentation { source in
                outputURL.withUnsafeFileSystemRepresentation { target in
                    renamex_np(source!, target!, UInt32(RENAME_EXCL))
                }
            }
            if status == 0 { return outputURL }
            let code = errno
            if code == EEXIST { continue }
            throw NSError(
                domain: NSPOSIXErrorDomain,
                code: Int(code),
                userInfo: [NSFilePathErrorKey: outputURL.path]
            )
        }
    }

    private func normalized(_ image: CIImage) -> CIImage {
        image.transformed(by: CGAffineTransform(
            translationX: -image.extent.minX,
            y: -image.extent.minY
        ))
    }
}
