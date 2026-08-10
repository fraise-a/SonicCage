import ServiceManagement

enum LaunchAtLoginStatus: Equatable {
    case enabled
    case needsApproval
    case disabled
    case unavailable

    var isRequested: Bool {
        self == .enabled || self == .needsApproval
    }
}

/// Uses macOS's supported Background Items mechanism. Because SonicCage is
/// an LSUIElement app, an approved login launch appears only in the menu bar.
@MainActor
final class LaunchAtLoginService {
    private let service = SMAppService.mainApp

    var status: LaunchAtLoginStatus {
        switch service.status {
        case .enabled:
            .enabled
        case .requiresApproval:
            .needsApproval
        case .notRegistered:
            .disabled
        case .notFound:
            .unavailable
        @unknown default:
            .unavailable
        }
    }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            guard service.status != .enabled else { return }
            try service.register()
        } else {
            guard service.status != .notRegistered else { return }
            try service.unregister()
        }
    }

    func openSystemSettings() {
        SMAppService.openSystemSettingsLoginItems()
    }
}
