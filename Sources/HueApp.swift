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
                Button("Capturer sur le Bureau") { model.capture() }
                    .disabled(!model.canRequestCapture)
                Button("Afficher la dernière capture") { model.revealLastCapture() }
                    .disabled(model.lastCapture == nil)
            }
            CommandMenu("Image") {
                Button("Tourner à gauche") { model.rotate(-1) }
                Button("Tourner à droite") { model.rotate(1) }
                Divider()
                Button("Réinitialiser l’orientation") { model.resetOrientation() }
                Divider()
                Button(model.isToolbarVisible ? "Masquer les outils" : "Afficher les outils") { model.toggleToolbar() }
            }
            CommandGroup(replacing: .help) {
                Button("À propos de Hue") {
                    NSApp.orderFrontStandardAboutPanel(options: [
                        .applicationName: "Hue",
                        .applicationVersion: "1.0",
                        .version: "1",
                        .credits: NSAttributedString(string: "Un visualiseur simple pour vos documents.\nCaméra • Rotation • Capture sur le Bureau")
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
