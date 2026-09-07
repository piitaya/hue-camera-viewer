import AppKit
import Combine
import Foundation

@MainActor
final class AppModel: ObservableObject {
    let camera: CameraEngine
    let isDemo: Bool
    @Published private(set) var orientation: ImageOrientation
    @Published private(set) var isSaving = false
    @Published private(set) var isToolbarVisible = true
    @Published private(set) var dockEdge: DockEdge = .right
    @Published private(set) var lastCapture: URL?
    @Published private(set) var notice: String?
    @Published var errorMessage: String?
    private let saveQueue = DispatchQueue(label: "app.hue.save", qos: .userInitiated)
    private var noticeTask: Task<Void, Never>?
    private var cameraChanges: AnyCancellable?
    private var capturePending = false

    init() {
        isDemo = ProcessInfo.processInfo.arguments.contains("--demo")
        camera = CameraEngine(demo: isDemo)
        if !isDemo, let visible = UserDefaults.standard.object(forKey: "hue.toolbarVisible") as? Bool {
            isToolbarVisible = visible
        }
        if !isDemo, let storedEdge = UserDefaults.standard.string(forKey: "hue.dockEdge"),
           let edge = DockEdge(rawValue: storedEdge) {
            dockEdge = edge
        }
        if !isDemo,
           let data = UserDefaults.standard.data(forKey: "hue.orientation"),
           let stored = try? JSONDecoder().decode(ImageOrientation.self, from: data) {
            orientation = stored
        } else {
            orientation = ImageOrientation()
        }
        camera.setOrientation(orientation)
        cameraChanges = Publishers.CombineLatest3(
            camera.$state.removeDuplicates(),
            camera.frames.$image.map { $0 != nil }.removeDuplicates(),
            camera.$isTransforming.removeDuplicates()
        ).sink { [weak self] values in
            guard let self else { return }
            self.objectWillChange.send()
            if !values.2, self.capturePending {
                // @Published notifies before the assignment; wait until the new
                // frame and transform flag have both been committed.
                DispatchQueue.main.async { [weak self] in
                    guard let self, self.capturePending, !self.camera.isTransforming else { return }
                    self.capturePending = false
                    self.capture()
                }
            }
        }
    }

    var canCapture: Bool {
        canRequestCapture && !camera.isTransforming
    }

    var canRequestCapture: Bool {
        camera.state == .running && camera.image != nil && !isSaving
    }

    func rotate(_ direction: Int) {
        orientation.quarterTurns = (orientation.quarterTurns + direction + 4) % 4
        commitOrientation()
    }

    func resetOrientation() {
        orientation = ImageOrientation()
        commitOrientation()
    }

    private func commitOrientation() {
        camera.setOrientation(orientation)
        if !isDemo, let data = try? JSONEncoder().encode(orientation) {
            UserDefaults.standard.set(data, forKey: "hue.orientation")
        }
    }

    func capture() {
        guard canRequestCapture else { return }
        if camera.isTransforming {
            capturePending = true
            return
        }
        guard let image = camera.image else { return }
        guard let directory = captureDirectory() else {
            errorMessage = "Le dossier Bureau est introuvable."
            return
        }
        isSaving = true
        let demoCapture = isDemo
        saveQueue.async { [weak self] in
            let result = Result {
                if demoCapture {
                    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
                }
                return try ImageProcessor().writePNG(image, to: directory)
            }
            DispatchQueue.main.async {
                guard let self else { return }
                self.isSaving = false
                switch result {
                case .success(let url):
                    self.lastCapture = url
                    self.showNotice(self.isDemo ? "Capture de démonstration enregistrée" : "Capture enregistrée sur le Bureau")
                case .failure(let error):
                    self.errorMessage = "La capture n’a pas pu être enregistrée.\n\nVérifiez l’accès au Bureau dans Réglages Système → Confidentialité et sécurité → Fichiers et dossiers → Hue.\n\n" + error.localizedDescription
                }
            }
        }
    }

    private func captureDirectory() -> URL? {
        // The demo keeps generated test captures out of the user's Desktop.
        if isDemo {
            let args = ProcessInfo.processInfo.arguments
            if let index = args.firstIndex(of: "--capture-directory"), index + 1 < args.count {
                return URL(fileURLWithPath: args[index + 1], isDirectory: true)
            }
            return FileManager.default.temporaryDirectory.appendingPathComponent("Hue-Demo", isDirectory: true)
        }
        return FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask).first
    }

    func revealLastCapture() {
        guard let lastCapture else { return }
        NSWorkspace.shared.activateFileViewerSelecting([lastCapture])
    }

    func openCameraPrivacy() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera") {
            NSWorkspace.shared.open(url)
        }
    }

    func toggleToolbar() {
        isToolbarVisible.toggle()
        if !isDemo {
            UserDefaults.standard.set(isToolbarVisible, forKey: "hue.toolbarVisible")
        }
    }

    func setDockEdge(_ edge: DockEdge) {
        dockEdge = edge
        if !isDemo { UserDefaults.standard.set(edge.rawValue, forKey: "hue.dockEdge") }
    }

    private func showNotice(_ message: String) {
        noticeTask?.cancel()
        notice = message
        noticeTask = Task { [weak self] in
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }
            self?.notice = nil
        }
    }
}
