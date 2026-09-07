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
                    .disabled(!model.canRequestCapture)
                Button("Show Last Capture") { model.revealLastCapture() }
                    .disabled(model.lastCapture == nil)
            }
            CommandMenu("Image") {
                Button("Rotate Left") { model.rotate(-1) }
                Button("Rotate Right") { model.rotate(1) }
                Divider()
                Button("Reset Orientation") { model.resetOrientation() }
                Divider()
                Button(model.isToolbarVisible ? NSLocalizedString("Hide Controls", comment: "Image menu when controls are visible") : NSLocalizedString("Show Controls", comment: "Image menu when controls are hidden")) { model.toggleToolbar() }
            }
            CommandGroup(replacing: .help) {
                Button("About Hue") {
                    NSApp.orderFrontStandardAboutPanel(options: [
                        .applicationName: "Hue",
                        .applicationVersion: "1.0",
                        .version: "1",
                        .credits: NSAttributedString(string: NSLocalizedString("A simple viewer for your documents.\nCamera • Rotation • Capture to Desktop", comment: "About panel description"))
                    ])
                }
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
