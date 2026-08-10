import Carbon
import Foundation

/// A user-chosen keyboard combination registered through Carbon's global
/// hot-key service.
struct GlobalShortcut: Equatable {
    let keyCode: UInt32
    let modifiers: UInt32
    let keyDisplay: String

    static let defaultEmergency = GlobalShortcut(
        keyCode: UInt32(kVK_ANSI_L),
        modifiers: UInt32(optionKey) | UInt32(cmdKey),
        keyDisplay: "L"
    )

    var displayName: String {
        var display = ""
        if modifiers & UInt32(controlKey) != 0 { display += "⌃" }
        if modifiers & UInt32(optionKey) != 0 { display += "⌥" }
        if modifiers & UInt32(shiftKey) != 0 { display += "⇧" }
        if modifiers & UInt32(cmdKey) != 0 { display += "⌘" }
        return display + keyDisplay
    }

    /// A bare key would be far too easy to trigger while playing.
    var hasSafetyModifier: Bool {
        let safetyModifiers = UInt32(controlKey) | UInt32(optionKey) | UInt32(cmdKey)
        return modifiers & safetyModifiers != 0
    }
}
