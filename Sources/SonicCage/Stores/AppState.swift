import AppKit
import ApplicationServices
import Combine
import SwiftUI
import UniformTypeIdentifiers

@MainActor
final class AppState: ObservableObject {
    @Published var isArmed: Bool { didSet { persistAndRefresh() } }
    @Published var topMargin: CGFloat { didSet { persistAndRefresh() } }
    @Published var leadingMargin: CGFloat { didSet { persistAndRefresh() } }
    @Published var bottomMargin: CGFloat { didSet { persistAndRefresh() } }
    @Published var trailingMargin: CGFloat { didSet { persistAndRefresh() } }
    @Published var keepsOneDisplay: Bool { didSet { persistAndRefresh() } }
    @Published private(set) var accessibilityGranted: Bool
    @Published private(set) var effectiveIsActive = false
    @Published private(set) var currentFrontmostApp = "No active application"
    @Published private(set) var lastError: String?
    @Published private(set) var target: AppTarget
    @Published private(set) var emergencyShortcut: GlobalShortcut
    @Published private(set) var emergencyShortcutError: String?
    @Published private(set) var launchAtLoginStatus: LaunchAtLoginStatus
    @Published private(set) var launchAtLoginError: String?

    private let defaults = UserDefaults.standard
    private let confinement = PointerConfinementService()
    private let launchAtLogin = LaunchAtLoginService()
    private var observers: [NSObjectProtocol] = []
    private lazy var shortcut = GlobalShortcutManager(shortcut: emergencyShortcut) { [weak self] in
        Task { @MainActor in self?.toggleArmed() }
    }

    init() {
        isArmed = defaults.object(forKey: Keys.isArmed) as? Bool ?? true
        topMargin = CGFloat(defaults.object(forKey: Keys.topMargin) as? Double ?? 2)
        leadingMargin = CGFloat(defaults.object(forKey: Keys.leadingMargin) as? Double ?? 2)
        bottomMargin = CGFloat(defaults.object(forKey: Keys.bottomMargin) as? Double ?? 16)
        trailingMargin = CGFloat(defaults.object(forKey: Keys.trailingMargin) as? Double ?? 2)
        keepsOneDisplay = defaults.object(forKey: Keys.keepsOneDisplay) as? Bool ?? true
        let restoredShortcut = GlobalShortcut(
            keyCode: UInt32(defaults.object(forKey: Keys.emergencyShortcutKeyCode) as? Int
                ?? Int(GlobalShortcut.defaultEmergency.keyCode)),
            modifiers: UInt32(defaults.object(forKey: Keys.emergencyShortcutModifiers) as? Int
                ?? Int(GlobalShortcut.defaultEmergency.modifiers)),
            keyDisplay: defaults.string(forKey: Keys.emergencyShortcutKeyDisplay)
                ?? GlobalShortcut.defaultEmergency.keyDisplay
        )
        emergencyShortcut = restoredShortcut.hasSafetyModifier
            ? restoredShortcut
            : .defaultEmergency
        accessibilityGranted = false
        lastError = nil
        emergencyShortcutError = nil
        launchAtLoginStatus = .disabled
        launchAtLoginError = nil

        let name = defaults.string(forKey: Keys.targetName) ?? AppTarget.sonicDreamTeam.displayName
        let identifier = defaults.string(forKey: Keys.targetBundleIdentifier)
        let path = defaults.string(forKey: Keys.targetBundlePath)
        target = AppTarget(
            displayName: name,
            bundleIdentifier: identifier,
            bundlePath: path,
            bundleFileName: defaults.string(forKey: Keys.targetBundleFileName)
                ?? (identifier == nil && path == nil ? AppTarget.sonicDreamTeam.bundleFileName : nil)
        )

        refreshLaunchAtLoginStatus()
        refreshAccessibilityStatus()
        observeApplicationChanges()
        _ = shortcut
        if !shortcut.isRegistered {
            emergencyShortcutError = "\(emergencyShortcut.displayName) could not be registered. Choose a different shortcut or use Turn Off from the menu bar before playing."
        }
        refresh()
    }

    func toggleArmed() {
        isArmed.toggle()
    }

    func setEmergencyShortcut(_ newShortcut: GlobalShortcut) {
        guard newShortcut.hasSafetyModifier else {
            emergencyShortcutError = "Choose a shortcut with Command, Option, or Control so it cannot be triggered by accident."
            return
        }

        guard shortcut.update(shortcut: newShortcut) else {
            emergencyShortcutError = "\(newShortcut.displayName) is already in use by macOS or another app. Choose another shortcut."
            return
        }

        emergencyShortcut = newShortcut
        defaults.set(Int(newShortcut.keyCode), forKey: Keys.emergencyShortcutKeyCode)
        defaults.set(Int(newShortcut.modifiers), forKey: Keys.emergencyShortcutModifiers)
        defaults.set(newShortcut.keyDisplay, forKey: Keys.emergencyShortcutKeyDisplay)
        emergencyShortcutError = nil
    }

    func restoreDefaultEmergencyShortcut() {
        setEmergencyShortcut(.defaultEmergency)
    }

    func reportInvalidEmergencyShortcut() {
        emergencyShortcutError = "Choose a shortcut with Command, Option, or Control so it cannot be triggered by accident."
    }

    func requestAccessibility() {
        // This is the documented Accessibility option key. A literal avoids a
        // Swift 6 false-positive around the imported mutable C global.
        let options = ["AXTrustedCheckOptionPrompt": true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
        refreshAccessibilityStatus()
        // The system panel is asynchronous. Recheck after the user returns from it.
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { [weak self] in
            self?.refresh()
        }
    }

    func openAccessibilitySettings() {
        requestAccessibility()
        guard let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    private func refreshAccessibilityStatus() {
        accessibilityGranted = AXIsProcessTrusted() || PointerConfinementService.canControlPointer()
    }

    func refresh() {
        refreshAccessibilityStatus()
        currentFrontmostApp = NSWorkspace.shared.frontmostApplication?.localizedName ?? "No active application"
        let shouldConstrain = isArmed && accessibilityGranted && targetIsFrontmost()

        confinement.update(
            margins: .init(
                top: topMargin,
                leading: leadingMargin,
                bottom: bottomMargin,
                trailing: trailingMargin
            ),
            keepsOneDisplay: keepsOneDisplay
        )

        if shouldConstrain {
            if !confinement.start() {
                lastError = "macOS could not create the mouse control service. Re-enable Accessibility permission, then try again."
            } else {
                lastError = nil
            }
        } else {
            confinement.stop()
        }
        effectiveIsActive = confinement.isActive
    }

    func chooseTargetApplication() {
        let panel = NSOpenPanel()
        panel.title = "Choose the game to protect"
        panel.message = "SonicCage only confines the pointer while this app is frontmost."
        panel.prompt = "Choose App"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.applicationBundle]

        guard panel.runModal() == .OK, let url = panel.url else { return }
        let bundle = Bundle(url: url)
        target = AppTarget(
            displayName: bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
                ?? bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String
                ?? url.deletingPathExtension().lastPathComponent,
            bundleIdentifier: bundle?.bundleIdentifier,
            bundlePath: url.path,
            bundleFileName: url.deletingPathExtension().lastPathComponent
        )
        persistTarget()
        refresh()
    }

    func restoreSonicDreamTeam() {
        target = .sonicDreamTeam
        persistTarget()
        refresh()
    }

    var launchAtLoginIsRequested: Bool {
        launchAtLoginStatus.isRequested
    }

    func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try launchAtLogin.setEnabled(enabled)
            launchAtLoginError = nil
        } catch {
            launchAtLoginError = "macOS could not update the login setting: \(error.localizedDescription)"
        }
        refreshLaunchAtLoginStatus()
    }

    func refreshLaunchAtLoginStatus() {
        launchAtLoginStatus = launchAtLogin.status
    }

    func openLoginItemSettings() {
        launchAtLogin.openSystemSettings()
    }

    var statusText: String {
        if effectiveIsActive { return "Caging pointer in \(target.displayName)" }
        if !isArmed { return "Off" }
        if !accessibilityGranted { return "Needs Accessibility permission" }
        return "On — waiting for \(target.displayName)"
    }

    private func observeApplicationChanges() {
        let center = NSWorkspace.shared.notificationCenter
        observers = [
            center.addObserver(forName: NSWorkspace.didActivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in self?.refresh() }
            },
            center.addObserver(forName: NSWorkspace.didDeactivateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in self?.refresh() }
            },
            center.addObserver(forName: NSWorkspace.didTerminateApplicationNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in self?.refresh() }
            },
            NotificationCenter.default.addObserver(forName: NSApplication.didBecomeActiveNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in self?.refresh() }
            },
            NotificationCenter.default.addObserver(forName: NSApplication.willTerminateNotification, object: nil, queue: .main) { [weak self] _ in
                Task { @MainActor [weak self] in self?.confinement.stop() }
            }
        ]
    }

    private func targetIsFrontmost() -> Bool {
        guard let app = NSWorkspace.shared.frontmostApplication else { return false }
        if let identifier = target.bundleIdentifier {
            return app.bundleIdentifier == identifier
        }
        if let path = target.bundlePath {
            return app.bundleURL?.path == path
        }
        if let bundleFileName = target.bundleFileName,
           let activeFileName = app.bundleURL?.deletingPathExtension().lastPathComponent,
           activeFileName.caseInsensitiveCompare(bundleFileName) == .orderedSame {
            return true
        }
        return app.localizedName?.caseInsensitiveCompare(target.displayName) == .orderedSame
    }

    private func persistAndRefresh() {
        defaults.set(isArmed, forKey: Keys.isArmed)
        defaults.set(Double(topMargin), forKey: Keys.topMargin)
        defaults.set(Double(leadingMargin), forKey: Keys.leadingMargin)
        defaults.set(Double(bottomMargin), forKey: Keys.bottomMargin)
        defaults.set(Double(trailingMargin), forKey: Keys.trailingMargin)
        defaults.set(keepsOneDisplay, forKey: Keys.keepsOneDisplay)
        refresh()
    }

    private func persistTarget() {
        defaults.set(target.displayName, forKey: Keys.targetName)
        defaults.set(target.bundleIdentifier, forKey: Keys.targetBundleIdentifier)
        defaults.set(target.bundlePath, forKey: Keys.targetBundlePath)
        defaults.set(target.bundleFileName, forKey: Keys.targetBundleFileName)
    }

    private enum Keys {
        static let isArmed = "isArmed"
        static let topMargin = "topMargin"
        static let leadingMargin = "leadingMargin"
        static let bottomMargin = "bottomMargin"
        static let trailingMargin = "trailingMargin"
        static let keepsOneDisplay = "keepsOneDisplay"
        static let targetName = "targetName"
        static let targetBundleIdentifier = "targetBundleIdentifier"
        static let targetBundlePath = "targetBundlePath"
        static let targetBundleFileName = "targetBundleFileName"
        static let emergencyShortcutKeyCode = "emergencyShortcutKeyCode"
        static let emergencyShortcutModifiers = "emergencyShortcutModifiers"
        static let emergencyShortcutKeyDisplay = "emergencyShortcutKeyDisplay"
    }
}
