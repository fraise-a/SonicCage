import SwiftUI

struct StatusMenuView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        Text(state.statusText)

        Button(state.isArmed ? "Turn Off" : "Turn On") {
            state.toggleArmed()
        }

        Divider()

        Button("Choose Game…") {
            state.chooseTargetApplication()
        }

        if !state.accessibilityGranted {
            Button("Open Accessibility Settings…") {
                state.openAccessibilitySettings()
            }
        }

        SettingsLink {
            Text("Settings…")
        }

        Divider()

        Text("Emergency: \(state.emergencyShortcut.displayName)")
            .foregroundStyle(.secondary)

        Button("Quit SonicCage") {
            NSApp.terminate(nil)
        }
        .keyboardShortcut("q")
    }
}
