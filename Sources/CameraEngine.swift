import AppKit
import AVFoundation
import Combine
import CoreImage

struct CameraChoice: Identifiable, Equatable {
    let id: String
    let name: String
    let isHUE: Bool
}

enum CameraState: Equatable {
    case idle, requestingPermission, starting, running, noCamera, denied
    case failed(String)
}

/// Frame updates are observed only by the preview, independently of controls.
final class CameraFrames: ObservableObject {
    @Published fileprivate(set) var image: CGImage?
}

/// Public methods and published values belong to the main thread. Capture and
/// image conversion have separate serial queues; the lock protects their handoff.
final class CameraEngine: NSObject, ObservableObject {
    @Published private(set) var devices: [CameraChoice] = []
    @Published private(set) var selectedDeviceID: String?
    let frames = CameraFrames()
    var image: CGImage? { frames.image }
    @Published private(set) var isTransforming = false
    @Published private(set) var state: CameraState = .idle
    @Published private(set) var resolution = ""

    private let demo: Bool
    private let session = AVCaptureSession()
    private let sessionQueue = DispatchQueue(label: "fr.hue.camera.session", qos: .userInitiated)
    private let frameQueue = DispatchQueue(label: "fr.hue.camera.frames", qos: .userInitiated)
    private let processor = ImageProcessor()
    private let lock = NSLock()
    private var observers: [NSObjectProtocol] = []

    // Main-thread control state.
    private var wantsRunning = false
    private var permissionRequestInFlight = false
    private var cameraEpoch = 0
    private var orientationRevision = 0

    private struct Frame {
        let image: CGImage
        let epoch: Int
        let revision: Int
    }

    // Every access to the following state is protected by lock.
    private var epoch = 0
    private var revision = 0
    private var orientation = ImageOrientation()
    private var acceptsFrames = false
    private var activeOutput: ObjectIdentifier?
    private var latestRawImage: CIImage?
    private var nextFrameTime = 0.0
    private var pendingFrame: Frame?
    private var deliveryScheduled = false

    init(demo: Bool = false) {
        self.demo = demo
        super.init()
        guard !demo else { return }
        let center = NotificationCenter.default
        for name in [AVCaptureDevice.wasConnectedNotification, AVCaptureDevice.wasDisconnectedNotification] {
            observers.append(center.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                self?.devicesChanged()
            })
        }
        observers.append(center.addObserver(forName: AVCaptureSession.runtimeErrorNotification,
                                             object: session, queue: .main) { [weak self] note in
            guard let self, self.wantsRunning else { return }
            let error = note.userInfo?[AVCaptureSessionErrorKey] as? NSError
            if error?.code == AVError.deviceWasDisconnected.rawValue || error?.code == AVError.deviceNotConnected.rawValue {
                _ = self.refreshDevices()
                self.suspend(.noCamera)
            } else {
                self.suspend(.failed(error?.localizedDescription ?? NSLocalizedString("The camera could not start. Unplug it, then plug it back in.", comment: "Camera error")))
            }
        })
        observers.append(center.addObserver(forName: AVCaptureSession.wasInterruptedNotification,
                                             object: session, queue: .main) { [weak self] _ in
            guard let self, self.wantsRunning else { return }
            self.suspend(.failed(NSLocalizedString("The camera is temporarily unavailable. Close other apps that are using it.", comment: "Camera error")))
        })
        observers.append(center.addObserver(forName: AVCaptureSession.interruptionEndedNotification,
                                             object: session, queue: .main) { [weak self] _ in
            guard let self, self.wantsRunning else { return }
            self.resumeSelectedCamera()
        })
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
        let captureSession = session
        sessionQueue.async { if captureSession.isRunning { captureSession.stopRunning() } }
    }

    func start() {
        precondition(Thread.isMainThread)
        guard !wantsRunning else { return }
        wantsRunning = true
        if demo {
            startDemo()
            return
        }
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            resumeSelectedCamera(preferHUE: true)
        case .notDetermined:
            state = .requestingPermission
            guard !permissionRequestInFlight else { return }
            permissionRequestInFlight = true
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.permissionRequestInFlight = false
                    guard self.wantsRunning else { return }
                    if granted { self.resumeSelectedCamera(preferHUE: true) }
                    else { self.suspend(.denied) }
                }
            }
        case .denied, .restricted:
            suspend(.denied)
        @unknown default:
            suspend(.denied)
        }
    }

    func stop() {
        precondition(Thread.isMainThread)
        wantsRunning = false
        suspend(.idle)
    }

    func retry() {
        precondition(Thread.isMainThread)
        stop()
        start()
    }

    func selectCamera(id: String) {
        precondition(Thread.isMainThread)
        guard !demo, wantsRunning, AVCaptureDevice.authorizationStatus(for: .video) == .authorized else { return }
        selectedDeviceID = id
        UserDefaults.standard.set(id, forKey: "hue.cameraID")
        resumeSelectedCamera()
    }

    func setOrientation(_ newOrientation: ImageOrientation) {
        precondition(Thread.isMainThread)
        orientationRevision += 1
        lock.lock()
        orientation = newOrientation
        revision = orientationRevision
        pendingFrame = nil
        nextFrameTime = 0
        let raw = latestRawImage
        let currentEpoch = epoch
        let currentRevision = revision
        let enabled = acceptsFrames
        lock.unlock()
        guard enabled, let raw else { return }
        isTransforming = true
        frameQueue.async { [weak self] in
            self?.render(raw, orientation: newOrientation, epoch: currentEpoch, revision: currentRevision)
        }
    }

    private static var externalCameraType: AVCaptureDevice.DeviceType {
        if #available(macOS 14.0, *) { return .external }
        return .externalUnknown
    }

    private func discoverDevices() -> [AVCaptureDevice] {
        let found = AVCaptureDevice.DiscoverySession(deviceTypes: [Self.externalCameraType, .builtInWideAngleCamera],
                                                     mediaType: .video, position: .unspecified).devices
        return found.sorted {
            let lhs = Self.isHUE($0), rhs = Self.isHUE($1)
            if lhs != rhs { return lhs }
            return $0.localizedName.localizedStandardCompare($1.localizedName) == .orderedAscending
        }
    }

    private static func isHUE(_ device: AVCaptureDevice) -> Bool {
        device.localizedName.range(of: "hue", options: .caseInsensitive) != nil
    }

    private func refreshDevices() -> [AVCaptureDevice] {
        let found = discoverDevices()
        devices = found.map { CameraChoice(id: $0.uniqueID, name: $0.localizedName, isHUE: Self.isHUE($0)) }
        return found
    }

    private func devicesChanged() {
        guard wantsRunning, AVCaptureDevice.authorizationStatus(for: .video) == .authorized else { return }
        let found = refreshDevices()
        // A disconnected selection remains selected. Reconnecting that device
        // resumes it, but an absent document camera never turns on the face camera.
        if let selectedDeviceID, !found.contains(where: { $0.uniqueID == selectedDeviceID }) {
            if let hue = found.first(where: Self.isHUE) { beginCamera(hue) }
            else { suspend(.noCamera) }
            return
        }
        if let hue = found.first(where: Self.isHUE), hue.uniqueID != selectedDeviceID {
            beginCamera(hue)
        } else if (state != .running && state != .starting) || selectedDeviceID == nil {
            resumeSelectedCamera()
        }
    }

    private func resumeSelectedCamera(preferHUE: Bool = false) {
        guard wantsRunning else { return }
        let found = refreshDevices()
        let rememberedID = UserDefaults.standard.string(forKey: "hue.cameraID")
        let chosen: AVCaptureDevice?
        if preferHUE, let hue = found.first(where: Self.isHUE) {
            chosen = hue
        } else if let selectedDeviceID {
            chosen = found.first { $0.uniqueID == selectedDeviceID }
        } else {
            chosen = found.first(where: Self.isHUE)
                ?? found.first { $0.uniqueID == rememberedID }
                ?? found.first { $0.deviceType == Self.externalCameraType }
                ?? found.first
        }
        guard let chosen else {
            suspend(.noCamera)
            return
        }
        beginCamera(chosen)
    }

    private func invalidateFrames() {
        cameraEpoch += 1
        lock.lock()
        epoch = cameraEpoch
        acceptsFrames = false
        activeOutput = nil
        latestRawImage = nil
        pendingFrame = nil
        nextFrameTime = 0
        lock.unlock()
        frames.image = nil
        isTransforming = false
        resolution = ""
    }

    private func suspend(_ newState: CameraState) {
        invalidateFrames()
        state = newState
        sessionQueue.async { [weak self] in
            guard let self else { return }
            if self.session.isRunning { self.session.stopRunning() }
        }
    }

    private func beginCamera(_ device: AVCaptureDevice) {
        invalidateFrames()
        selectedDeviceID = device.uniqueID
        UserDefaults.standard.set(device.uniqueID, forKey: "hue.cameraID")
        state = .starting
        let currentEpoch = cameraEpoch
        DispatchQueue.main.asyncAfter(deadline: .now() + 8) { [weak self] in
            guard let self, self.wantsRunning, self.cameraEpoch == currentEpoch, self.state == .starting else { return }
            self.suspend(.failed(NSLocalizedString("The camera is not sending any images. Check the USB cable and close other apps that are using it.", comment: "Camera error")))
        }
        sessionQueue.async { [weak self] in
            guard let self, self.isCurrent(currentEpoch) else { return }
            do {
                try self.configureSession(device: device, epoch: currentEpoch)
                guard self.isCurrent(currentEpoch) else { return }
                self.session.startRunning()
                if !self.session.isRunning {
                    self.reportFailure(NSLocalizedString("The camera is not responding. Check its connection and close other apps that are using it.", comment: "Camera error"), epoch: currentEpoch)
                }
            } catch {
                self.reportFailure(error.localizedDescription, epoch: currentEpoch)
            }
        }
    }

    private func isCurrent(_ expectedEpoch: Int) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return epoch == expectedEpoch
    }

    private func configureSession(device: AVCaptureDevice, epoch expectedEpoch: Int) throws {
        if session.isRunning { session.stopRunning() }
        session.beginConfiguration()
        defer { session.commitConfiguration() }
        session.inputs.forEach { session.removeInput($0) }
        session.outputs.forEach { session.removeOutput($0) }
        let input = try AVCaptureDeviceInput(device: device)
        guard session.canAddInput(input) else { throw cameraError(NSLocalizedString("This camera could not be opened.", comment: "Camera error")) }
        session.addInput(input)
        if session.canSetSessionPreset(.high) { session.sessionPreset = .high }

        try device.lockForConfiguration()
        defer { device.unlockForConfiguration() }
        if let format = device.formats.filter({ !$0.videoSupportedFrameRateRanges.isEmpty }).max(by: {
            let a = CMVideoFormatDescriptionGetDimensions($0.formatDescription)
            let b = CMVideoFormatDescriptionGetDimensions($1.formatDescription)
            return Int64(a.width) * Int64(a.height) < Int64(b.width) * Int64(b.height)
        }) {
            device.activeFormat = format
            // The output is always capped at 30 fps; also cap the device when
            // its native format supports that rate, to reduce unnecessary work.
            if format.videoSupportedFrameRateRanges.contains(where: { $0.minFrameRate <= 30 && $0.maxFrameRate >= 30 }) {
                device.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 30)
            }
        }

        let output = AVCaptureVideoDataOutput()
        output.alwaysDiscardsLateVideoFrames = true
        output.setSampleBufferDelegate(self, queue: frameQueue)
        guard session.canAddOutput(output) else { throw cameraError(NSLocalizedString("This camera’s video stream is unavailable.", comment: "Camera error")) }
        session.addOutput(output)
        if let connection = output.connection(with: .video) {
            if connection.isVideoMirroringSupported {
                connection.automaticallyAdjustsVideoMirroring = false
                connection.isVideoMirrored = false
            }
            if #available(macOS 14.0, *), connection.isVideoRotationAngleSupported(0) {
                connection.videoRotationAngle = 0
            }
        }
        let dimensions = CMVideoFormatDescriptionGetDimensions(device.activeFormat.formatDescription)
        // Explicit native dimensions prevent the session preset from choosing
        // a smaller preview buffer on macOS.
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA,
            kCVPixelBufferWidthKey as String: Int(dimensions.width),
            kCVPixelBufferHeightKey as String: Int(dimensions.height)
        ]
        lock.lock()
        if epoch == expectedEpoch {
            activeOutput = ObjectIdentifier(output)
            acceptsFrames = true
        }
        lock.unlock()
    }

    private func cameraError(_ message: String) -> NSError {
        NSError(domain: "fr.hue.camera", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
    }

    private func reportFailure(_ message: String, epoch expectedEpoch: Int) {
        DispatchQueue.main.async { [weak self] in
            guard let self, self.wantsRunning, self.cameraEpoch == expectedEpoch else { return }
            self.suspend(.failed(message))
        }
    }

    private func render(_ raw: CIImage, orientation: ImageOrientation, epoch: Int, revision: Int) {
        lock.lock()
        let isCurrent = acceptsFrames && self.epoch == epoch && self.revision == revision
        lock.unlock()
        guard isCurrent else { return }
        autoreleasepool {
            do {
                let rendered = try processor.render(raw, orientation: orientation)
                lock.lock()
                guard acceptsFrames, self.epoch == epoch, self.revision == revision else {
                    lock.unlock()
                    return
                }
                pendingFrame = Frame(image: rendered, epoch: epoch, revision: revision)
                let shouldSchedule = !deliveryScheduled
                deliveryScheduled = true
                lock.unlock()
                if shouldSchedule {
                    DispatchQueue.main.async { [weak self] in self?.deliverLatestFrame() }
                }
            } catch {
                reportFailure(String(format: NSLocalizedString("The camera image could not be displayed: %@", comment: "Camera render failure followed by the system error"), error.localizedDescription), epoch: epoch)
            }
        }
    }

    private func deliverLatestFrame() {
        lock.lock()
        let frame = pendingFrame
        pendingFrame = nil
        deliveryScheduled = false
        lock.unlock()
        guard wantsRunning, let frame, cameraEpoch == frame.epoch, orientationRevision == frame.revision else { return }
        frames.image = frame.image
        if isTransforming { isTransforming = false }
        let size = "\(frame.image.width) × \(frame.image.height)"
        if resolution != size { resolution = size }
        if state != .running { state = .running }
    }

    private func startDemo() {
        invalidateFrames()
        let raw = Self.demoImage()
        devices = [CameraChoice(id: "demo", name: NSLocalizedString("HUE HD Pro · Demo", comment: "Synthetic camera name"), isHUE: true)]
        selectedDeviceID = "demo"
        state = .starting
        lock.lock()
        acceptsFrames = true
        latestRawImage = raw
        let currentOrientation = orientation
        let currentEpoch = epoch
        let currentRevision = revision
        lock.unlock()
        frameQueue.async { [weak self] in
            self?.render(raw, orientation: currentOrientation, epoch: currentEpoch, revision: currentRevision)
        }
    }

    private static func demoImage() -> CIImage {
        let background = CIImage(color: CIColor(red: 0.94, green: 0.93, blue: 0.90))
            .cropped(to: CGRect(x: 0, y: 0, width: 800, height: 600))
        let square = CIImage(color: CIColor(red: 0.25, green: 0.65, blue: 0.50))
            .cropped(to: CGRect(x: 100, y: 300, width: 200, height: 200))
        let rectangle = CIImage(color: CIColor(red: 0.95, green: 0.65, blue: 0.25))
            .cropped(to: CGRect(x: 500, y: 100, width: 180, height: 120))
        return rectangle.composited(over: square.composited(over: background))
    }
}

extension CameraEngine: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }
        let raw = CIImage(cvPixelBuffer: pixelBuffer)
        let timestamp = CMTimeGetSeconds(CMSampleBufferGetPresentationTimeStamp(sampleBuffer))
        let now = timestamp.isFinite ? timestamp : ProcessInfo.processInfo.systemUptime
        lock.lock()
        guard acceptsFrames, activeOutput == ObjectIdentifier(output) else {
            lock.unlock()
            return
        }
        latestRawImage = raw
        guard now + 0.00001 >= nextFrameTime else {
            lock.unlock()
            return
        }
        nextFrameTime = nextFrameTime == 0 ? now + 1.0 / 30.0 : max(nextFrameTime + 1.0 / 30.0, now)
        let currentOrientation = orientation
        let currentEpoch = epoch
        let currentRevision = revision
        lock.unlock()
        render(raw, orientation: currentOrientation, epoch: currentEpoch, revision: currentRevision)
    }
}
