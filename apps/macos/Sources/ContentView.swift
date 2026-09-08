import AppKit
import SwiftUI

private let dockAccent = Color(red: 245 / 255, green: 182 / 255, blue: 49 / 255)
private let dockSecondaryAccent = Color(red: 201 / 255, green: 93 / 255, blue: 53 / 255)
private let stageColor = Color(red: 0.045, green: 0.05, blue: 0.055)
private let forceClassicDock = ProcessInfo.processInfo.arguments.contains("--classic-dock")

struct ContentView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var camera: CameraEngine
    @State private var dragOrigin: CGPoint?
    @State private var dragCenter: CGPoint?
    @State private var previewEdge: DockEdge?
    @State private var gripHovered = false
    @State private var captureHovered = false
    @State private var panOffset: CGSize = .zero
    @State private var panStart: CGSize?
    @StateObject private var wheelZoom = WheelZoomMonitor()

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                stageColor
                if camera.state == .running {
                    CameraImageView(frames: camera.frames)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                        .scaleEffect(model.zoom)
                        .offset(panOffset)
                        .gesture(panGesture(in: geometry.size), including: model.isZoomed ? .all : .subviews)
                } else {
                    emptyState
                        .frame(maxWidth: 360)
                        .padding(32)
                }
            }
            .clipped()
            .background(WindowReader { wheelZoom.stageView = $0 })
            .overlay { dockOverlay(in: geometry.size) }
            .overlay(alignment: .topTrailing) {
                if model.isZoomed {
                    zoomPill
                        .padding(14)
                        .transition(.opacity)
                }
            }
            .overlay(alignment: .bottom) {
                if let notice = model.notice {
                    Button(action: model.revealLastCapture) {
                        Label(notice, systemImage: "checkmark.circle.fill")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundStyle(.primary)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 11)
                            .background(.ultraThinMaterial, in: Capsule())
                            .overlay(Capsule().strokeBorder(.primary.opacity(0.10)))
                    }
                    .buttonStyle(.plain)
                    .help("Show Capture in Finder")
                    .padding(.bottom, model.dockEdge == .bottom ? (model.isToolbarVisible ? 92 : 50) : 20)
                    .transition(.opacity)
                }
            }
            .overlay(alignment: .bottomLeading) {
                if model.isDemo {
                    Text("Demo")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.42))
                        .padding(16)
                        .allowsHitTesting(false)
                }
            }
            .onChange(of: model.zoom) { _ in
                panOffset = clampedPan(panOffset, in: geometry.size)
            }
            .onChange(of: camera.selectedDeviceID) { _ in
                panOffset = .zero
            }
        }
        .background(stageColor)
        .tint(dockAccent)
        .animation(.easeOut(duration: 0.18), value: model.isZoomed)
        .onAppear { wheelZoom.install(handleWheel) }
        .onDisappear { wheelZoom.remove() }
        .sheet(isPresented: $model.isShowingShortcuts) {
            ShortcutsView(isPresented: $model.isShowingShortcuts)
        }
        .alert("Unable to Save", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

    // MARK: Zoom

    /// Scroll wheels and trackpad pinches zoom the preview around the pointer.
    private func handleWheel(_ event: NSEvent, at pointer: CGPoint?, in size: CGSize) {
        guard camera.state == .running else { return }
        let factor: CGFloat
        switch event.type {
        case .scrollWheel:
            let delta = event.hasPreciseScrollingDeltas ? event.scrollingDeltaY / 2 : event.scrollingDeltaY * 6
            factor = exp(delta * 0.01)
        case .magnify:
            factor = 1 + event.magnification
        default:
            return
        }
        let previous = model.zoom
        model.zoom(by: factor)
        guard let pointer, previous > 0 else { return }
        // Keep the image point under the pointer in place: the pointer's offset
        // from the stage centre scales with the zoom, the pan absorbs the rest.
        let ratio = model.zoom / previous
        let anchor = CGSize(width: pointer.x - size.width / 2, height: pointer.y - size.height / 2)
        panOffset = clampedPan(CGSize(width: anchor.width - (anchor.width - panOffset.width) * ratio,
                                      height: anchor.height - (anchor.height - panOffset.height) * ratio), in: size)
    }

    private func panGesture(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 2)
            .onChanged { value in
                let start = panStart ?? panOffset
                if panStart == nil { panStart = start }
                panOffset = clampedPan(CGSize(width: start.width + value.translation.width,
                                              height: start.height + value.translation.height), in: size)
            }
            .onEnded { _ in panStart = nil }
    }

    /// Panning stops where the magnified image meets the edge of the stage.
    private func clampedPan(_ offset: CGSize, in size: CGSize) -> CGSize {
        guard model.isZoomed, let image = camera.image, size.width > 0, size.height > 0 else { return .zero }
        let imageWidth = CGFloat(image.width), imageHeight = CGFloat(image.height)
        let scale = min(size.width / imageWidth, size.height / imageHeight) * model.zoom
        let limitX = max(0, (imageWidth * scale - size.width) / 2)
        let limitY = max(0, (imageHeight * scale - size.height) / 2)
        return CGSize(width: min(max(offset.width, -limitX), limitX),
                      height: min(max(offset.height, -limitY), limitY))
    }

    private var zoomPill: some View {
        Button(action: model.resetZoom) {
            HStack(spacing: 6) {
                Text(verbatim: "\(model.zoomPercent) %")
                    .font(.system(size: 12, weight: .medium).monospacedDigit())
                Image(systemName: "xmark")
                    .font(.system(size: 9, weight: .bold))
                    .frame(width: 18, height: 18)
                    .background(.primary.opacity(0.09), in: Circle())
            }
            .foregroundStyle(.primary)
            .padding(.leading, 12)
            .padding(.trailing, 6)
            .padding(.vertical, 6)
            .background(.ultraThinMaterial, in: Capsule())
            .overlay(Capsule().strokeBorder(.primary.opacity(0.10)))
        }
        .buttonStyle(.plain)
        .help("Zoom to 100 %")
        .accessibilityLabel("Zoom to 100 %")
        .accessibilityValue(Text(verbatim: "\(model.zoomPercent) %"))
    }

    // MARK: Dock

    private func dockOverlay(in size: CGSize) -> some View {
        let edge = model.dockEdge
        let dimensions = dockSize(for: edge)
        let handleSize = edge.isVertical ? CGSize(width: 26, height: 46) : CGSize(width: 46, height: 26)
        let activeSize = model.isToolbarVisible ? dimensions : handleSize
        let anchoredCenter = DockGeometry.center(for: edge, in: size, dockSize: activeSize, inset: model.isToolbarVisible ? 14 : 8)
        let center = model.isToolbarVisible
            ? dragCenter.map { DockGeometry.clampedCenter($0, in: size, dockSize: dimensions) } ?? anchoredCenter
            : anchoredCenter
        return ZStack {
            if let target = previewEdge, dragCenter != nil, model.isToolbarVisible {
                let targetSize = dockSize(for: target)
                RoundedRectangle(cornerRadius: 29)
                    .fill(dockSecondaryAccent.opacity(0.16))
                    .overlay {
                        RoundedRectangle(cornerRadius: 29)
                            .strokeBorder(.black.opacity(0.45), lineWidth: 3)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 29)
                            .strokeBorder(.white.opacity(0.90), style: StrokeStyle(lineWidth: 1, dash: [5, 5]))
                    }
                    .frame(width: targetSize.width, height: targetSize.height)
                    .position(DockGeometry.center(for: target, in: size, dockSize: targetSize))
                    .animation(.spring(response: 0.30, dampingFraction: 0.82), value: target)
                    .transition(.opacity)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            // Both sets of controls stay alive inside one persistent dock
            // surface, so folding the dock never recreates its material.
            ZStack {
                dock(for: edge, in: size)
                    .opacity(model.isToolbarVisible ? 1 : 0)
                    .allowsHitTesting(model.isToolbarVisible)
                    .accessibilityHidden(!model.isToolbarVisible)
                showDockButton(for: edge, size: handleSize)
                    .opacity(model.isToolbarVisible ? 0 : 1)
                    .allowsHitTesting(!model.isToolbarVisible)
                    .accessibilityHidden(model.isToolbarVisible)
            }
            .frame(width: activeSize.width, height: activeSize.height)
            .clipShape(Capsule())
            .modifier(DockSurface(forceClassic: forceClassicDock))
            .position(center)
            .animation(.spring(response: 0.36, dampingFraction: 0.88), value: model.isToolbarVisible)
        }
        .frame(width: size.width, height: size.height)
        .coordinateSpace(name: "cameraStage")
    }

    /// Grip 26, five 42-point buttons, one divider (11), hide button 30,
    /// seven 4-point gaps and 10-point end padding.
    private func dockSize(for edge: DockEdge) -> CGSize {
        edge.isVertical ? CGSize(width: 58, height: 325) : CGSize(width: 325, height: 58)
    }

    private func dock(for edge: DockEdge, in size: CGSize) -> some View {
        let layout = edge.isVertical ? AnyLayout(VStackLayout(spacing: 4)) : AnyLayout(HStackLayout(spacing: 4))
        let dimensions = dockSize(for: edge)
        return layout {
            dragHandle(for: edge, in: size)
            cameraMenu
            DockButton("Rotate Left", icon: .rotateLeft) { model.rotate(-1) }
            DockButton("Rotate Right", icon: .rotateRight) { model.rotate(1) }
            zoomButton(for: edge)
            dockDivider(for: edge)
            captureButton
            DockButton("Hide Controls", icon: chevron(for: edge, inward: false), size: 30, iconSize: 15) {
                model.toggleToolbar()
            }
        }
        .padding(.horizontal, edge.isVertical ? 8 : 10)
        .padding(.vertical, edge.isVertical ? 10 : 8)
        .frame(width: dimensions.width, height: dimensions.height)
    }

    private func dockDivider(for edge: DockEdge) -> some View {
        Rectangle()
            .fill(.primary.opacity(0.16))
            .frame(width: edge.isVertical ? 22 : 1, height: edge.isVertical ? 1 : 22)
            .padding(edge.isVertical ? .vertical : .horizontal, 5)
            .accessibilityHidden(true)
    }

    private func dragHandle(for edge: DockEdge, in size: CGSize) -> some View {
        DockGlyph(icon: .grip)
            .foregroundStyle(.primary)
            .rotationEffect(.degrees(edge.isVertical ? 90 : 0))
            .frame(width: edge.isVertical ? 42 : 26, height: edge.isVertical ? 26 : 42)
            .background(.primary.opacity(gripHovered ? 0.10 : 0), in: RoundedRectangle(cornerRadius: 7))
            .contentShape(Rectangle())
            .gesture(dockDrag(in: size))
            .onHover { hovering in
                gripHovered = hovering
                if hovering { NSCursor.openHand.set() } else { NSCursor.arrow.set() }
            }
            .help("Move Controls")
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Move Controls")
            .accessibilityAction(named: Text("Move to Left Edge")) { moveDock(to: .left) }
            .accessibilityAction(named: Text("Move to Right Edge")) { moveDock(to: .right) }
            .accessibilityAction(named: Text("Move to Top Edge")) { moveDock(to: .top) }
            .accessibilityAction(named: Text("Move to Bottom Edge")) { moveDock(to: .bottom) }
    }

    private func dockDrag(in size: CGSize) -> some Gesture {
        DragGesture(minimumDistance: 3, coordinateSpace: .named("cameraStage"))
            .onChanged { value in
                let dimensions = dockSize(for: model.dockEdge)
                let origin = dragOrigin ?? DockGeometry.center(for: model.dockEdge, in: size, dockSize: dimensions)
                if dragOrigin == nil { dragOrigin = origin }
                NSCursor.closedHand.set()
                let translated = CGPoint(x: origin.x + value.translation.width, y: origin.y + value.translation.height)
                let center = DockGeometry.clampedCenter(translated, in: size, dockSize: dimensions)
                dragCenter = center
                previewEdge = DockGeometry.nearestEdge(to: center, in: size, preferred: previewEdge ?? model.dockEdge)
            }
            .onEnded { value in
                let dimensions = dockSize(for: model.dockEdge)
                let origin = dragOrigin ?? DockGeometry.center(for: model.dockEdge, in: size, dockSize: dimensions)
                let translated = CGPoint(x: origin.x + value.translation.width, y: origin.y + value.translation.height)
                let center = DockGeometry.clampedCenter(translated, in: size, dockSize: dimensions)
                let target = DockGeometry.nearestEdge(to: center, in: size, preferred: previewEdge ?? model.dockEdge)
                moveDock(to: target)
            }
    }

    private func moveDock(to edge: DockEdge) {
        NSCursor.arrow.set()
        gripHovered = false
        withAnimation(.spring(response: 0.42, dampingFraction: 0.82)) {
            model.setDockEdge(edge)
            dragCenter = nil
            dragOrigin = nil
            previewEdge = nil
        }
    }

    private func chevron(for edge: DockEdge, inward: Bool) -> DockIcon {
        switch edge {
        case .left: return inward ? .chevronRight : .chevronLeft
        case .right: return inward ? .chevronLeft : .chevronRight
        case .top: return inward ? .chevronDown : .chevronUp
        case .bottom: return inward ? .chevronUp : .chevronDown
        }
    }

    /// The popover opens away from the edge the dock sits on.
    private func popoverArrowEdge(for edge: DockEdge) -> Edge {
        switch edge {
        case .left: return .trailing
        case .right: return .leading
        case .top: return .bottom
        case .bottom: return .top
        }
    }

    private var cameraMenu: some View {
        Menu {
            if camera.devices.isEmpty { Text("No cameras available") }
            ForEach(camera.devices) { device in
                Button {
                    camera.selectCamera(id: device.id)
                } label: {
                    if camera.selectedDeviceID == device.id {
                        Label(device.name, systemImage: "checkmark")
                    } else {
                        Text(device.name)
                    }
                }
            }
            Divider()
            Button("Keyboard Shortcuts…") { model.isShowingShortcuts = true }
        } label: {
            Text(" ").frame(width: 42, height: 42)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .frame(width: 42, height: 42)
        .tint(.primary)
        // Draw the glyph outside the native menu label, which otherwise
        // scales template images down to a small NSMenu control icon.
        .overlay {
            DockGlyph(icon: .source)
            .foregroundStyle(.primary)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .help(String(format: NSLocalizedString("Choose Camera\n%@", comment: "Camera picker tooltip, including the selected camera name"), selectedCameraName))
        .accessibilityLabel("Choose Camera")
        .accessibilityValue(selectedCameraName)
    }

    private var selectedCameraName: String {
        camera.devices.first { $0.id == camera.selectedDeviceID }?.name ?? NSLocalizedString("No camera selected", comment: "Fallback camera name")
    }

    private func zoomButton(for edge: DockEdge) -> some View {
        DockButton("Zoom", icon: .zoom, isActive: model.isShowingZoom) {
            model.isShowingZoom.toggle()
        }
        .popover(isPresented: $model.isShowingZoom, arrowEdge: popoverArrowEdge(for: edge)) {
            ZoomPanel(model: model)
        }
    }

    private var captureButton: some View {
        Button(action: model.capture) {
            ZStack {
                Circle().fill(.primary.opacity(captureHovered && model.canRequestCapture ? 0.08 : 0))
                if model.isSaving {
                    ProgressView().controlSize(.small).tint(.primary)
                } else {
                    DockGlyph(icon: .capture)
                        .foregroundStyle(model.canRequestCapture ? Color.primary : Color.secondary)
                }
            }
            .frame(width: 42, height: 42)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!model.canRequestCapture)
        .onHover { captureHovered = $0 }
        .help("Save a Capture to the Desktop")
        .accessibilityLabel(model.isSaving ? NSLocalizedString("Saving", comment: "Capture button while saving") : NSLocalizedString("Capture to Desktop", comment: "Capture button accessibility label"))
    }

    private func showDockButton(for edge: DockEdge, size: CGSize) -> some View {
        Button(action: model.toggleToolbar) {
            DockGlyph(icon: chevron(for: edge, inward: true), size: 15)
                .foregroundStyle(.primary)
                .frame(width: size.width, height: size.height)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help("Show Controls")
        .accessibilityLabel("Show Controls")
    }

    // MARK: Empty state

    private var emptyState: some View {
        VStack(spacing: 12) {
            if camera.state == .starting || camera.state == .requestingPermission {
                ProgressView().controlSize(.regular).tint(.white.opacity(0.7))
                    .padding(.bottom, 7)
            } else {
                Image(systemName: camera.state == .denied ? "lock" : "video")
                    .font(.system(size: 30, weight: .light))
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.bottom, 6)
            }
            Text(emptyTitle)
                .font(.system(size: 18, weight: .medium))
                .foregroundStyle(.white.opacity(0.85))
            Text(emptyMessage)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.48))
                .multilineTextAlignment(.center)
                .lineSpacing(3)
            if camera.state == .denied {
                Button("Open Settings") { model.openCameraPrivacy() }
                    .buttonStyle(.bordered)
                    .padding(.top, 5)
            }
        }
    }

    private var emptyTitle: String {
        switch camera.state {
        case .idle, .noCamera: return NSLocalizedString("Connect your camera", comment: "Camera empty state")
        case .requestingPermission: return NSLocalizedString("Allow camera access", comment: "Camera empty state")
        case .starting: return NSLocalizedString("Starting the camera…", comment: "Camera empty state")
        case .denied: return NSLocalizedString("Camera access is disabled", comment: "Camera empty state")
        case .failed: return NSLocalizedString("Camera unavailable", comment: "Camera empty state")
        case .running: return NSLocalizedString("Waiting for an image…", comment: "Camera empty state")
        }
    }

    private var emptyMessage: String {
        switch camera.state {
        case .idle, .noCamera:
            return NSLocalizedString("Connect your camera to a USB port on your Mac.", comment: "Camera empty state")
        case .requestingPermission:
            return NSLocalizedString("Allow access when macOS asks to show the preview.", comment: "Camera empty state")
        case .starting, .running:
            return NSLocalizedString("Preparing the preview.", comment: "Camera empty state")
        case .denied:
            return NSLocalizedString("Enable Hue in System Settings → Privacy & Security → Camera.", comment: "Camera empty state")
        case .failed(let message):
            return message
        }
    }
}

/// The zoom slider opens from the dock's magnifier; the wheel and pinch zoom too.
private struct ZoomPanel: View {
    @ObservedObject var model: AppModel
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Zoom")
                Spacer()
                Text(verbatim: "\(model.zoomPercent) %")
                    .font(.system(size: 12).monospacedDigit())
                    .foregroundStyle(.secondary)
            }
            Slider(value: Binding(
                get: { model.zoom },
                set: { model.setZoom($0) }
            ), in: AppModel.zoomRange)
            .controlSize(.small)
            .accessibilityLabel("Zoom")
        }
        .padding(16)
        .frame(width: 230)
        // The glass dock flips its content to dark over a dark stage, and the
        // popover content inherits that; its window must follow the same scheme.
        .background(WindowAppearance(colorScheme: colorScheme))
    }
}

/// Applies the SwiftUI color scheme to the AppKit window hosting the view.
private struct WindowAppearance: NSViewRepresentable {
    let colorScheme: ColorScheme

    func makeNSView(context: Context) -> AppearanceView {
        AppearanceView()
    }

    func updateNSView(_ nsView: AppearanceView, context: Context) {
        nsView.colorScheme = colorScheme
    }

    final class AppearanceView: NSView {
        var colorScheme: ColorScheme = .light {
            didSet { apply() }
        }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            apply()
        }

        private func apply() {
            window?.appearance = NSAppearance(named: colorScheme == .dark ? .darkAqua : .aqua)
        }
    }
}

/// One line per action, mirroring the shortcuts declared in the app menus.
private struct ShortcutsView: View {
    @Binding var isPresented: Bool

    private let shortcuts: [(LocalizedStringKey, String)] = [
        ("Capture to Desktop", "⌘ S"),
        ("Rotate Left", "⌘ ←"),
        ("Rotate Right", "⌘ →"),
        ("Zoom In", "⌘ +"),
        ("Zoom Out", "⌘ −"),
        ("Zoom to 100 %", "⌘ 0"),
        ("Hide or Show Controls", "⌥ ⌘ T"),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Keyboard Shortcuts")
                .font(.system(size: 15, weight: .semibold))
            VStack(spacing: 0) {
                ForEach(Array(shortcuts.enumerated()), id: \.offset) { index, shortcut in
                    HStack {
                        Text(shortcut.0)
                        Spacer()
                        Text(verbatim: shortcut.1)
                            .font(.system(size: 12, weight: .medium).monospacedDigit())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 6))
                    }
                    .padding(.vertical, 7)
                    if index < shortcuts.count - 1 {
                        Divider()
                    }
                }
            }
            Text("Zoom also follows the scroll wheel or a pinch on the trackpad.")
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            HStack {
                Spacer()
                Button("Done") { isPresented = false }
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(20)
        .frame(width: 340)
    }
}

/// Zoom events are only honoured in the hosting window; the image settings
/// popover and the shortcuts sheet live in their own windows. The handler
/// receives the pointer in stage coordinates (origin top-left) and the stage size.
private final class WheelZoomMonitor: ObservableObject {
    weak var stageView: NSView?
    private var monitor: Any?

    func install(_ handler: @escaping (NSEvent, CGPoint?, CGSize) -> Void) {
        guard monitor == nil else { return }
        monitor = NSEvent.addLocalMonitorForEvents(matching: [.scrollWheel, .magnify]) { [weak self] event in
            if let self, let stage = self.stageView, let window = stage.window, event.window === window {
                let local = stage.convert(event.locationInWindow, from: nil)
                let size = stage.bounds.size
                let pointer = stage.bounds.contains(local)
                    ? CGPoint(x: local.x, y: stage.isFlipped ? local.y : size.height - local.y)
                    : nil
                handler(event, pointer, size)
            }
            return event
        }
    }

    func remove() {
        if let monitor { NSEvent.removeMonitor(monitor) }
        monitor = nil
    }

    deinit { remove() }
}

/// Reports the stage's backing NSView once it is attached to a window.
private struct WindowReader: NSViewRepresentable {
    let onAttach: (NSView?) -> Void

    func makeNSView(context: Context) -> NSView {
        WindowReportingView(onAttach: onAttach)
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    private final class WindowReportingView: NSView {
        let onAttach: (NSView?) -> Void

        init(onAttach: @escaping (NSView?) -> Void) {
            self.onAttach = onAttach
            super.init(frame: .zero)
        }

        required init?(coder: NSCoder) { return nil }

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            onAttach(window == nil ? nil : self)
        }
    }
}

private struct DockSurface: ViewModifier {
    let forceClassic: Bool

    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 26.0, *), !forceClassic {
            content.glassEffect(.regular, in: Capsule())
        } else {
            content
                .background(.regularMaterial, in: Capsule())
                .overlay(Capsule().strokeBorder(.primary.opacity(0.12), lineWidth: 0.5))
                .shadow(color: .black.opacity(0.16), radius: 12, y: 4)
        }
    }
}

private struct CameraImageView: View {
    @ObservedObject var frames: CameraFrames

    var body: some View {
        if let image = frames.image {
            Image(decorative: image, scale: 1, orientation: .up)
                .resizable()
                .interpolation(.high)
                .aspectRatio(contentMode: .fit)
                .accessibilityLabel("Camera Preview")
        } else {
            Color.clear
        }
    }
}

private enum DockIcon: String {
    case source = "DockSource"
    case zoom = "DockZoom"
    case capture = "DockCapture"
    case rotateRight = "DockRotateRight"
    case rotateLeft = "DockRotateLeft"
    case grip = "DockGrip"
    case chevronUp = "DockChevronUp"
    case chevronDown = "DockChevronDown"
    case chevronLeft = "DockChevronLeft"
    case chevronRight = "DockChevronRight"
}

private struct DockGlyph: View {
    let icon: DockIcon
    var size: CGFloat = 21

    var body: some View {
        Image(icon.rawValue)
            .renderingMode(.template)
            .resizable()
            .scaledToFit()
            .frame(width: size, height: size)
            .accessibilityHidden(true)
    }
}

private struct DockButton: View {
    let title: LocalizedStringKey
    let icon: DockIcon
    var size: CGFloat = 42
    var iconSize: CGFloat = 21
    var isActive = false
    let action: () -> Void
    @State private var hovering = false

    init(_ title: LocalizedStringKey, icon: DockIcon,
         size: CGFloat = 42, iconSize: CGFloat = 21, isActive: Bool = false, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.size = size
        self.iconSize = iconSize
        self.isActive = isActive
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            DockGlyph(icon: icon, size: iconSize)
                .foregroundStyle(.primary)
                .frame(width: size, height: size)
                .background(.primary.opacity(isActive ? 0.14 : hovering ? 0.08 : 0), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(Text(title))
        .accessibilityLabel(Text(title))
    }
}
