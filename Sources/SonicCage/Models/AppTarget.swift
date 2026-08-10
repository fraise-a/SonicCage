import Foundation

struct AppTarget: Equatable {
    var displayName: String
    var bundleIdentifier: String?
    var bundlePath: String?
    /// The `.app` bundle name without its extension. This catches games that
    /// do not provide a conventional bundle identifier.
    var bundleFileName: String?

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
