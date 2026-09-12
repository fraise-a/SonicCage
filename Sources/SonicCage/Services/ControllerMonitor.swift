import Foundation
import GameController

/// Reports whether macOS currently has a supported game controller connected.
final class ControllerMonitor {
    private var observers: [NSObjectProtocol] = []

    var isControllerConnected: Bool {
        !GCController.controllers().isEmpty
    }

    init(onChange: @escaping @Sendable () -> Void) {
        let center = NotificationCenter.default
        observers = [
            center.addObserver(
                forName: .GCControllerDidConnect,
                object: nil,
                queue: .main
            ) { _ in
                onChange()
            },
            center.addObserver(
                forName: .GCControllerDidDisconnect,
                object: nil,
                queue: .main
            ) { _ in
                onChange()
            }
        ]
    }

    deinit {
        observers.forEach(NotificationCenter.default.removeObserver)
    }
}
