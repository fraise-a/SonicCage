import Foundation

struct AppTarget: Codable, Equatable, Identifiable {
    var displayName: String
    var bundleIdentifier: String?
    var bundlePath: String?
    /// The `.app` bundle name without its extension. This catches games that
    /// do not provide a conventional bundle identifier.
    var bundleFileName: String?

    /// Stable across app launches and independent of how the name is displayed.
    var id: String {
        if let bundleIdentifier { return "identifier:\(bundleIdentifier.lowercased())" }
        if let bundlePath { return "path:\(bundlePath)" }
        if let bundleFileName { return "file:\(bundleFileName.lowercased())" }
        return "name:\(displayName.lowercased())"
    }

    static let sonicDreamTeam = AppTarget(
        displayName: "Sonic Dream Team",
        bundleIdentifier: nil,
        bundlePath: nil,
        bundleFileName: "SonicDreamTeam"
    )

    /// Treat both the built-in choice and a manually selected SonicDreamTeam.app
    /// as the same protected game for the Settings controls.
    var isSonicDreamTeam: Bool {
        if let bundleFileName,
           bundleFileName.caseInsensitiveCompare(Self.sonicDreamTeam.bundleFileName ?? "") == .orderedSame {
            return true
        }
        return displayName.caseInsensitiveCompare(Self.sonicDreamTeam.displayName) == .orderedSame
    }
}
