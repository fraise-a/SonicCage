import SwiftUI

struct SettingsView: View {
    @EnvironmentObject private var state: AppState

    var body: some View {
        Form {
            Section("Status") {
                Toggle("Arm SonicCage", isOn: $state.isArmed)
                LabeledContent("Current state", value: state.statusText)

                if let error = state.lastError {
                    Text(error)
                        .foregroundStyle(.red)
                }
            }

            Section("Emergency Toggle") {
                HStack {
                    Text("Shortcut")
                    Spacer()
                    ShortcutRecorder(
                        shortcut: state.emergencyShortcut,
                        onCapture: { state.setEmergencyShortcut($0) },
                        onInvalidCapture: { state.reportInvalidEmergencyShortcut() }
                    )
                    .frame(width: 148, height: 28)
                }

                Button("Restore Default (⌥⌘L)") {
                    state.restoreDefaultEmergencyShortcut()
                }

                Text("The emergency toggle turns SonicCage on or off even while your game is in front. Use it as a quick escape if the pointer ever feels wrong or you need to reach the Dock; turn it on again to restore automatic protection. Click the shortcut above, then press the key combination you want. For safety, it must include Command, Option, or Control.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let error = state.emergencyShortcutError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Section("Protected App") {
                LabeledContent("App", value: state.target.displayName)
                HStack {
                    Button("Choose Another App…") {
                        state.chooseTargetApplication()
                    }
                    Button("Use Sonic Dream Team") {
                        state.restoreSonicDreamTeam()
                    }
                    .disabled(state.target.isSonicDreamTeam)
                    .help(state.target.isSonicDreamTeam ? "Sonic Dream Team is already selected." : "Use Sonic Dream Team as the protected app.")
                }
                Text("Sonic Dream Team is recognised as SonicDreamTeam.app. The cage only activates while this app is frontmost, and releases immediately when you switch away or the app quits.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Screen Edges") {
                marginRow("Top", value: $state.topMargin)
                marginRow("Left", value: $state.leadingMargin)
                marginRow("Bottom (Dock)", value: $state.bottomMargin)
                marginRow("Right", value: $state.trailingMargin)
                Text("Margins are in points. The default 16-point bottom margin keeps the Dock from being triggered; increase it if your Dock still appears.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Multiple Displays") {
                Toggle("Keep pointer on its starting display", isOn: $state.keepsOneDisplay)
                Text("When enabled, SonicCage uses the display under the pointer as the game comes forward and prevents crossing to another screen. Turn it off to apply the same edge margin while moving between displays.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Launch at Login") {
                Toggle("Launch SonicCage at login", isOn: Binding(
                    get: { state.launchAtLoginIsRequested },
                    set: { state.setLaunchAtLogin($0) }
                ))
                .onAppear {
                    state.refreshLaunchAtLoginStatus()
                }

                switch state.launchAtLoginStatus {
                case .enabled:
                    Text("SonicCage will start quietly in the menu bar after you log in.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                case .needsApproval:
                    Text("macOS needs your approval before it can run at login.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Button("Open Login Items Settings") {
                        state.openLoginItemSettings()
                    }
                case .disabled:
                    Text("Turn this on to start SonicCage quietly in the menu bar at login.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                case .unavailable:
                    Text("macOS could not read this app's login-item status. Make sure you are running SonicCage from its app bundle.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if let error = state.launchAtLoginError {
                    Text(error)
                        .foregroundStyle(.red)
                }
            }

            Section("Permission") {
                if state.accessibilityGranted {
                    Label("Accessibility permission is allowed.", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                } else {
                    Text("macOS requires Accessibility permission before an app may control the pointer. Enable the SonicCage entry here — an old Cursor Cage entry cannot authorize this renamed app.")
                    HStack {
                        Button("Open Accessibility Settings…") {
                            state.openAccessibilitySettings()
                        }
                        Button("Check Again") {
                            state.refresh()
                        }
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 510)
        .padding()
    }

    @ViewBuilder
    private func marginRow(_ label: String, value: Binding<CGFloat>) -> some View {
        HStack {
            Text(label)
            Spacer()
            Stepper(value: value, in: 0...100, step: 1) {
                Text("\(Int(value.wrappedValue)) pt")
                    .monospacedDigit()
                    .frame(width: 48, alignment: .trailing)
            }
        }
    }
}
