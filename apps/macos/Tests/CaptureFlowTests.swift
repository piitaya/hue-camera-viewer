import CoreGraphics
import CoreImage
import Foundation
import ImageIO

private enum TestFailure: Error, CustomStringConvertible {
    case assertion(String)
    var description: String {
        switch self { case .assertion(let message): return message }
    }
}

private func expect(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() { throw TestFailure.assertion(message) }
}

private func rgbaBytes(_ image: CGImage) -> [UInt8] {
    var bytes = [UInt8](repeating: 0, count: image.width * image.height * 4)
    bytes.withUnsafeMutableBytes { buffer in
        let context = CGContext(
            data: buffer.baseAddress, width: image.width, height: image.height,
            bitsPerComponent: 8, bytesPerRow: image.width * 4,
            space: CGColorSpace(name: CGColorSpace.sRGB)!,
            bitmapInfo: CGBitmapInfo.byteOrder32Big.rawValue | CGImageAlphaInfo.premultipliedLast.rawValue
        )!
        context.setBlendMode(.copy)
        context.interpolationQuality = .none
        context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
    }
    return bytes
}

@main
private struct CaptureFlowTests {
    @MainActor
    static func waitUntil(_ message: String, condition: () -> Bool) async throws {
        let deadline = ContinuousClock.now.advanced(by: .seconds(10))
        while !condition() {
            guard ContinuousClock.now < deadline else { throw TestFailure.assertion(message) }
            try await Task.sleep(for: .milliseconds(20))
        }
    }

    @MainActor
    static func main() async throws {
        // Refuse to construct AppModel unless test.sh supplies an isolated demo folder.
        let args = ProcessInfo.processInfo.arguments
        guard args.contains("--demo"),
              let index = args.firstIndex(of: "--capture-directory"), index + 1 < args.count else {
            throw TestFailure.assertion("Run this test with --demo --capture-directory <capture-flow.XXXXXX>.")
        }
        let folder = URL(fileURLWithPath: args[index + 1], isDirectory: true).standardizedFileURL
        try expect(folder.lastPathComponent.hasPrefix("capture-flow."), "A dedicated capture-flow test directory is required")
        let initialFiles = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
        try expect(initialFiles.isEmpty, "The capture test directory must start empty")

        let model = AppModel()
        try expect(model.isDemo, "The regression test must never start a real camera")
        model.camera.start()
        defer { model.camera.stop() }
        try await waitUntil("The synthetic camera did not deliver its initial frame") {
            model.camera.state == .running && model.camera.image != nil && !model.camera.isTransforming
        }
        guard let initialImage = model.camera.image else {
            throw TestFailure.assertion("The initial synthetic frame is missing")
        }
        try expect(initialImage.width != initialImage.height, "The fixture must have asymmetric dimensions")
        try expect(model.orientation.quarterTurns == 0, "Demo orientation must start at zero")

        // No suspension between the two user actions: capture must wait for the new frame.
        model.rotate(1)
        try expect(model.camera.isTransforming, "Rotation did not enter the pending-frame state")
        try expect(model.canRequestCapture && !model.canCapture, "Capture request should remain available while rotating")
        model.capture()
        try expect(!model.isSaving && model.lastCapture == nil, "Capture used the previous frame instead of waiting")

        try await waitUntil("The queued capture did not complete after rotation") {
            model.errorMessage != nil || (model.lastCapture != nil && !model.isSaving)
        }
        try expect(model.errorMessage == nil, "Capture failed: \(model.errorMessage ?? "unknown error")")
        guard let url = model.lastCapture,
              let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let captured = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            throw TestFailure.assertion("The completed capture is not a readable image")
        }
        try expect(url.deletingLastPathComponent().standardizedFileURL == folder, "Capture escaped the isolated demo directory")
        try expect(CGImageSourceGetType(source) as String? == "public.png", "Capture must be a PNG")
        try expect(captured.width == initialImage.height && captured.height == initialImage.width,
                   "The queued capture did not preserve native resolution after the 90-degree rotation")
        let expected = try ImageProcessor().render(CIImage(cgImage: initialImage), orientation: ImageOrientation(quarterTurns: 1))
        try expect(rgbaBytes(captured) == rgbaBytes(expected), "Capture pixels do not match the requested rotation")
        guard let currentPreview = model.camera.image else {
            throw TestFailure.assertion("The rotated preview frame is missing")
        }
        try expect(rgbaBytes(captured) == rgbaBytes(currentPreview), "Capture pixels do not match the displayed frame")

        // Allow any accidentally duplicated queued callback to become observable.
        try await Task.sleep(for: .milliseconds(100))
        let files = try FileManager.default.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)
        try expect(files.count == 1 && files[0].pathExtension == "png", "One capture request must produce exactly one PNG")
        try expect(!model.isSaving && !model.camera.isTransforming, "Capture or transformation remained pending")

        // The zoom is a display setting and never touches the camera frame.
        model.setZoom(2.5)
        try expect(model.isZoomed && model.zoomPercent == 250, "Zoom did not apply")
        model.setZoom(9)
        try expect(model.zoom == AppModel.zoomRange.upperBound, "Zoom escaped its range")
        model.resetZoom()
        try expect(!model.isZoomed, "Zoom did not reset")
        try expect(model.camera.image.map(rgbaBytes) == rgbaBytes(currentPreview), "Zooming must not change the camera frame")

        // Freezing holds the frame; rotation keeps re-orienting the held image.
        try expect(!model.isFrozen && model.canFreeze, "Freeze must be available while streaming")
        model.toggleFreeze()
        try expect(model.isFrozen, "Freeze did not apply")
        model.rotate(1)
        try await waitUntil("The frozen frame was not re-oriented") { !model.camera.isTransforming }
        guard let frozenImage = model.camera.image else {
            throw TestFailure.assertion("The frozen frame is missing")
        }
        let expectedFrozen = try ImageProcessor().render(CIImage(cgImage: initialImage), orientation: ImageOrientation(quarterTurns: 2))
        try expect(rgbaBytes(frozenImage) == rgbaBytes(expectedFrozen), "Rotation must apply to the frozen frame")
        try expect(model.isFrozen, "Rotation must not end the freeze")
        model.toggleFreeze()
        try expect(!model.isFrozen, "Resume did not apply")
        model.toggleFreeze()
        model.camera.stop()
        try expect(!model.isFrozen && !model.canFreeze, "Stopping the camera must end the freeze")

        print("PASS: immediate rotation/capture queues one PNG, preserves native dimensions, matches the rotated pixels and preview, zooms the preview without touching the frame, freezes and rotates the held frame, and uses only an isolated demo directory.")
    }
}
