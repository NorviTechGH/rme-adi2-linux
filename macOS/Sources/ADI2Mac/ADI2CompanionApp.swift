import SwiftUI
import AppKit

@main struct ADI2CompanionApp: App {
    @StateObject private var model = AppModel()
    var body: some Scene {
        WindowGroup("ADI-2 Companion") {
            ControlView(model:model)
                .onAppear {
                    if ProcessInfo.processInfo.arguments.contains("--demo") { model.startDemo() }
                }
        }
        .defaultSize(width:1120,height:800)
        .commands {
            CommandGroup(replacing:.newItem) {
                Button("Import EQ…", action:model.importProfile).keyboardShortcut("o")
                Button("Export Profile…", action:model.exportProfile).keyboardShortcut("s",modifiers:[.command,.shift])
            }
            CommandMenu("Device") {
                Button("Sync from Device", action:model.sync).keyboardShortcut("r").disabled(!model.canWrite)
                Button("Apply EQ to Both Channels", action:model.applyProfile).disabled(!model.canWrite && !model.demoMode)
                Divider()
                Button(model.demoMode ? "Leave Demo" : "Explore Demo") { if model.demoMode { model.stopDemo() } else { model.startDemo() } }
            }
            CommandGroup(replacing:.help) {
                Link("Setup and Support", destination:URL(string:"https://github.com/spencernorton/rme-adi2-linux/blob/main/macOS/SUPPORT.md")!)
                Button("Privacy Policy") { showPrivacy() }
            }
        }
    }
    private func showPrivacy() {
        let alert = NSAlert()
        alert.messageText = "Your audio setup stays on your Mac."
        alert.informativeText = "ADI-2 Companion collects no personal data, audio, analytics or crash telemetry. It communicates locally with the ADI-2 through CoreMIDI. EQ files are read or saved only where you choose. The app has no network capability.\n\nAn independent app, not affiliated with or endorsed by RME."
        alert.addButton(withTitle:"Done")
        alert.addButton(withTitle:"View Policy Online")
        if alert.runModal() == .alertSecondButtonReturn { NSWorkspace.shared.open(URL(string:"https://github.com/spencernorton/rme-adi2-linux/blob/main/macOS/PRIVACY.md")!) }
    }
}
