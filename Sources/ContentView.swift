import AppKit
import SwiftUI

private let dockAccent = Color(red: 0.64, green: 0.90, blue: 0.79)
private let stageColor = Color(red: 0.045, green: 0.05, blue: 0.055)

struct ContentView: View {
    @ObservedObject var model: AppModel
    @ObservedObject var camera: CameraEngine
    @State private var dragOrigin: CGPoint?
    @State private var dragCenter: CGPoint?
    @State private var previewEdge: DockEdge?
    @State private var gripHovered = false

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                stageColor
                if camera.state == .running {
                    CameraImageView(frames: camera.frames)
                        .frame(width: geometry.size.width, height: geometry.size.height)
                } else {
                    emptyState
                        .frame(maxWidth: 360)
                        .padding(32)
                }
            }
            .overlay { dockOverlay(in: geometry.size) }
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
                    .help("Afficher la capture dans le Finder")
                    .padding(.bottom, model.dockEdge == .bottom ? (model.isToolbarVisible ? 92 : 50) : 20)
                    .transition(.opacity)
                }
            }
            .overlay(alignment: .bottomLeading) {
                if model.isDemo {
                    Text("Démonstration")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.42))
                        .padding(16)
                        .allowsHitTesting(false)
                }
            }
        }
        .background(stageColor)
        .tint(dockAccent)
        .alert("Enregistrement impossible", isPresented: Binding(
            get: { model.errorMessage != nil },
            set: { if !$0 { model.errorMessage = nil } }
        )) {
            Button("OK", role: .cancel) { model.errorMessage = nil }
        } message: {
            Text(model.errorMessage ?? "")
        }
    }

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
                    .fill(dockAccent.opacity(0.16))
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
            // Both sets of controls stay alive inside one persistent glass
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
            .glassEffect(.regular, in: Capsule())
            .position(center)
            .animation(.spring(response: 0.36, dampingFraction: 0.88), value: model.isToolbarVisible)
        }
        .frame(width: size.width, height: size.height)
        .coordinateSpace(name: "cameraStage")
    }

    private func dockSize(for edge: DockEdge) -> CGSize {
        edge.isVertical ? CGSize(width: 58, height: 294) : CGSize(width: 294, height: 58)
    }

    private func dock(for edge: DockEdge, in size: CGSize) -> some View {
        let layout = edge.isVertical ? AnyLayout(VStackLayout(spacing: 4)) : AnyLayout(HStackLayout(spacing: 4))
        let dimensions = dockSize(for: edge)
        return layout {
            dragHandle(for: edge, in: size)
            cameraMenu
            dockDivider(for: edge)
            DockButton("Tourner à droite", symbol: "rotate.right") { model.rotate(1) }
            DockButton("Tourner à gauche", symbol: "rotate.left") { model.rotate(-1) }
            dockDivider(for: edge)
            captureButton
            DockButton("Masquer les commandes", symbol: chevron(for: edge, inward: false), size: 30, iconSize: 12) {
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
        VStack(spacing: 2) {
            Image(systemName: "ellipsis").frame(height: 5)
            Image(systemName: "ellipsis").frame(height: 5)
        }
            .font(.system(size: 17, weight: .bold))
            .foregroundStyle(.primary)
            .rotationEffect(.degrees(edge.isVertical ? 0 : 90))
            .frame(width: edge.isVertical ? 42 : 26, height: edge.isVertical ? 26 : 42)
            .background(.primary.opacity(gripHovered ? 0.10 : 0), in: RoundedRectangle(cornerRadius: 7))
            .contentShape(Rectangle())
            .gesture(dockDrag(in: size))
            .onHover { hovering in
                gripHovered = hovering
                if hovering { NSCursor.openHand.set() } else { NSCursor.arrow.set() }
            }
            .help("Déplacer les commandes")
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Déplacer les commandes")
            .accessibilityAction(named: Text("Placer à gauche")) { moveDock(to: .left) }
            .accessibilityAction(named: Text("Placer à droite")) { moveDock(to: .right) }
            .accessibilityAction(named: Text("Placer en haut")) { moveDock(to: .top) }
            .accessibilityAction(named: Text("Placer en bas")) { moveDock(to: .bottom) }
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

    private func chevron(for edge: DockEdge, inward: Bool) -> String {
        switch edge {
        case .left: return inward ? "chevron.right" : "chevron.left"
        case .right: return inward ? "chevron.left" : "chevron.right"
        case .top: return inward ? "chevron.down" : "chevron.up"
        case .bottom: return inward ? "chevron.up" : "chevron.down"
        }
    }

    private var cameraMenu: some View {
        Menu {
            if camera.devices.isEmpty { Text("Aucune caméra disponible") }
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
            Button("Actualiser les caméras") { camera.retry() }
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
            Image(systemName: "video")
            .resizable()
            .scaledToFit()
            .frame(width: 22, height: 18)
            .foregroundStyle(.primary)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
        }
        .help("Choisir la caméra\n" + selectedCameraName)
        .accessibilityLabel("Choisir la caméra")
        .accessibilityValue(selectedCameraName)
    }

    private var selectedCameraName: String {
        camera.devices.first { $0.id == camera.selectedDeviceID }?.name ?? "Aucune caméra sélectionnée"
    }

    private var captureButton: some View {
        Button(action: model.capture) {
            ZStack {
                Circle().fill(model.canRequestCapture ? dockAccent : Color.primary.opacity(0.12))
                if model.isSaving {
                    ProgressView().controlSize(.small).tint(.primary)
                } else {
                    Image(systemName: "camera.fill")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(model.canRequestCapture ? stageColor : Color.secondary)
                }
            }
            .frame(width: 42, height: 42)
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!model.canRequestCapture)
        .help("Capturer l’image sur le Bureau")
        .accessibilityLabel(model.isSaving ? "Enregistrement en cours" : "Capturer sur le Bureau")
    }

    private func showDockButton(for edge: DockEdge, size: CGSize) -> some View {
        Button(action: model.toggleToolbar) {
            Image(systemName: chevron(for: edge, inward: true))
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.primary)
                .frame(width: size.width, height: size.height)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .help("Afficher les commandes")
        .accessibilityLabel("Afficher les commandes")
    }

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
                Button("Ouvrir les réglages") { model.openCameraPrivacy() }
                    .buttonStyle(.bordered)
                    .padding(.top, 5)
                Button("Réessayer") { camera.retry() }
                    .buttonStyle(.plain)
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.65))
            } else if case .failed = camera.state {
                Button("Réessayer") { camera.retry() }
                    .buttonStyle(.bordered)
                    .padding(.top, 5)
            }
        }
    }

    private var emptyTitle: String {
        switch camera.state {
        case .idle, .noCamera: return "Branchez votre caméra"
        case .requestingPermission: return "Autorisez l’accès à la caméra"
        case .starting: return "La caméra démarre…"
        case .denied: return "L’accès à la caméra est désactivé"
        case .failed: return "La caméra est indisponible"
        case .running: return "Votre image arrive…"
        }
    }

    private var emptyMessage: String {
        switch camera.state {
        case .idle, .noCamera:
            return "Connectez la HUE à un port USB de votre Mac."
        case .requestingPermission:
            return "Acceptez la demande de macOS pour afficher l’aperçu."
        case .starting, .running:
            return "Préparation de l’aperçu."
        case .denied:
            return "Activez Hue dans Réglages Système → Confidentialité et sécurité → Caméra."
        case .failed(let message):
            return message
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
                .accessibilityLabel("Aperçu de la caméra")
        } else {
            Color.clear
        }
    }
}

private struct DockButton: View {
    let title: String
    let symbol: String
    var size: CGFloat = 42
    var iconSize: CGFloat = 17
    let action: () -> Void
    @State private var hovering = false

    init(_ title: String, symbol: String,
         size: CGFloat = 42, iconSize: CGFloat = 17, action: @escaping () -> Void) {
        self.title = title
        self.symbol = symbol
        self.size = size
        self.iconSize = iconSize
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: symbol)
                .font(.system(size: iconSize, weight: .medium))
                .foregroundStyle(.primary)
                .frame(width: size, height: size)
                .background(.primary.opacity(hovering ? 0.08 : 0), in: Circle())
                .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .help(title)
        .accessibilityLabel(title)
    }
}
