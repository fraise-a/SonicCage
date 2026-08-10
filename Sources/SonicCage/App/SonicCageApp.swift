import AppKit
import SwiftUI

@main
struct SonicCageApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var state: AppState

    init() {
        let newState = AppState()
        _state = StateObject(wrappedValue: newState)
    }

    var body: some Scene {
        MenuBarExtra {
            StatusMenuView()
                .environmentObject(state)
        } label: {
            Image(systemName: state.effectiveIsActive ? "lock.fill" : "lock.open")
                .accessibilityLabel("SonicCage")
        }
        .menuBarExtraStyle(.menu)

        Settings {
            SettingsView()
                .environmentObject(state)
        }
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        // SonicCage is deliberately a menu-bar utility; its controls live in the
        // status item and its settings window, rather than occupying the Dock.
        NSApp.setActivationPolicy(.accessory)
    }
}
