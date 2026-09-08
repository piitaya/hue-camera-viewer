import AppKit
import SwiftUI

@main
struct HueApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    @StateObject private var model = AppModel()

    var body: some Scene {
        Window("Hue", id: "main") {
            ContentView(model: model, camera: model.camera)
                .frame(minWidth: 520, minHeight: 520)
                .onAppear { model.camera.start() }
        }
        .defaultSize(width: 1100, height: 780)
        .windowStyle(.titleBar)
        .windowResizability(.contentMinSize)
        .commands {
            CommandGroup(replacing: .newItem) { }
            CommandGroup(replacing: .saveItem) {
                Button("Capture to Desktop") { model.capture() }
                    .keyboardShortcut("s", modifiers: .command)
                    .disabled(!model.canRequestCapture)
                Button("Show Last Capture") { model.revealLastCapture() }
                    .disabled(model.lastCapture == nil)
            }
            CommandMenu("Image") {
                Button("Rotate Left") { model.rotate(-1) }
                    .keyboardShortcut(.leftArrow, modifiers: .command)
                Button("Rotate Right") { model.rotate(1) }
                    .keyboardShortcut(.rightArrow, modifiers: .command)
                Button("Reset Orientation") { model.resetOrientation() }
                Divider()
                Button("Zoom In") { model.zoomIn() }
                    .keyboardShortcut("+", modifiers: .command)
                Button("Zoom Out") { model.zoomOut() }
                    .keyboardShortcut("-", modifiers: .command)
                Button("Zoom to 100 %") { model.resetZoom() }
                    .keyboardShortcut("0", modifiers: .command)
                Divider()
                Button(model.isToolbarVisible ? NSLocalizedString("Hide Controls", comment: "Image menu when controls are visible") : NSLocalizedString("Show Controls", comment: "Image menu when controls are hidden")) { model.toggleToolbar() }
                    .keyboardShortcut("t", modifiers: [.command, .option])
            }
            CommandGroup(replacing: .help) {
                Button("About Hue") {
                    NSApp.orderFrontStandardAboutPanel(options: [
                        .applicationName: "Hue",
                        .applicationVersion: "1.0",
                        .version: "1",
                        .credits: NSAttributedString(string: NSLocalizedString("A simple viewer for your documents.\nCamera • Rotation • Zoom • Capture to Desktop", comment: "About panel description"))
                    ])
                }
                Divider()
                Button("Keyboard Shortcuts…") { model.isShowingShortcuts = true }
            }
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { true }
}
