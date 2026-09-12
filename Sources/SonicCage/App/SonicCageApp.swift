import AppKit
import SwiftUI

@main
struct SonicCageApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var state: AppState
    @StateObject private var updater: SonicCageUpdater

    init() {
        let newState = AppState()
        _state = StateObject(wrappedValue: newState)
        _updater = StateObject(wrappedValue: SonicCageUpdater())
    }

    var body: some Scene {
        MenuBarExtra {
            StatusMenuView()
                .environmentObject(state)
                .environmentObject(updater)
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

    @MainActor
    static func showAboutSonicCage() {
        let bundle = Bundle.main
        let appName = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String ?? "SonicCage"
        let version = bundle.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.1"
        let build = bundle.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "11"
        let ownerName = NSFullUserName().trimmingCharacters(in: .whitespacesAndNewlines)
        let credits = NSAttributedString(
            string: ownerName.isEmpty ? "SonicCage" : "Created by \(ownerName)"
        )

        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: appName,
            .applicationVersion: version,
            .version: build,
            .credits: credits
        ])
        NSApp.activate()
    }
}
