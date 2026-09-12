import Combine
import Sparkle

/// Keeps Sparkle's standard controller alive for the complete lifetime of the
/// menu-bar app. The controller owns Sparkle's normal automatic schedule and
/// standard update UI; SonicCage does not implement its own updater protocol.
@MainActor
final class SonicCageUpdater: ObservableObject {
    @Published private(set) var canCheckForUpdates = false

    private let updaterController: SPUStandardUpdaterController

    init() {
        updaterController = SPUStandardUpdaterController(
            startingUpdater: true,
            updaterDelegate: nil,
            userDriverDelegate: nil
        )

        updaterController.updater
            .publisher(for: \.canCheckForUpdates)
            .receive(on: RunLoop.main)
            .assign(to: &$canCheckForUpdates)
    }

    func checkForUpdates() {
        guard canCheckForUpdates else { return }
        updaterController.checkForUpdates(nil)
    }
}
