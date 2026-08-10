import Carbon
import Foundation

/// Registers the user-selected, always-available escape hatch.
final class GlobalShortcutManager {
    private var eventHandler: EventHandlerRef?
    private var hotKey: EventHotKeyRef?
    private let action: () -> Void
    private(set) var shortcut: GlobalShortcut
    private(set) var isRegistered = false

    init(shortcut: GlobalShortcut, action: @escaping () -> Void) {
        self.shortcut = shortcut
        self.action = action
        install()
    }

    deinit {
        unregisterHotKey()
        if let eventHandler { RemoveEventHandler(eventHandler) }
    }

    /// Keeps the existing shortcut in place when macOS rejects the new one.
    func update(shortcut newShortcut: GlobalShortcut) -> Bool {
        guard newShortcut.hasSafetyModifier else { return false }
        guard newShortcut != shortcut else { return isRegistered }
        guard eventHandler != nil else { return false }

        let previousShortcut = shortcut
        unregisterHotKey()

        guard register(newShortcut) else {
            _ = register(previousShortcut)
            return false
        }

        shortcut = newShortcut
        return true
    }

    private func install() {
        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )
        let handlerStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            globalShortcutHandler,
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )

        guard handlerStatus == noErr else { return }

        isRegistered = register(shortcut)
    }

    @discardableResult
    private func register(_ shortcut: GlobalShortcut) -> Bool {
        let identifier = EventHotKeyID(signature: OSType(0x43414745), id: 1) // "CAGE"
        let didRegister = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.modifiers,
            identifier,
            GetApplicationEventTarget(),
            0,
            &hotKey
        ) == noErr
        isRegistered = didRegister
        return didRegister
    }

    private func unregisterHotKey() {
        if let hotKey {
            UnregisterEventHotKey(hotKey)
            self.hotKey = nil
        }
        isRegistered = false
    }

    fileprivate func invoke() {
        action()
    }
}

private let globalShortcutHandler: EventHandlerUPP = { _, _, userInfo in
    guard let userInfo else { return noErr }
    let manager = Unmanaged<GlobalShortcutManager>.fromOpaque(userInfo).takeUnretainedValue()
    manager.invoke()
    return noErr
}
