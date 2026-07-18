import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Menu bar only: no Dock icon (SPM executables have no Info.plist for LSUIElement)
        NSApp.setActivationPolicy(.accessory)
    }
}

@main
struct HomePerchApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var ha = HAClient()

    var body: some Scene {
        MenuBarExtra("HomePerch", systemImage: "house.fill") {
            PopoverView()
                .environmentObject(ha)
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(ha)
        }
    }
}
