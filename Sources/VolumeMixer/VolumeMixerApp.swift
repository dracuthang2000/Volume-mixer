import SwiftUI

@main
struct VolumeMixerApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        MenuBarExtra {
            MixerView(model: appDelegate.model)
        } label: {
            Image(systemName: "slider.vertical.3")
        }
        .menuBarExtraStyle(.window)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Created at launch so saved per-app volumes apply before the menu is first opened.
    let model = MixerModel()

    func applicationWillTerminate(_ notification: Notification) {
        model.shutdown()
    }
}
