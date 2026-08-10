import AppKit
import Carbon
import SwiftUI

/// A small AppKit bridge because SwiftUI has no native macOS shortcut recorder.
struct ShortcutRecorder: NSViewRepresentable {
    let shortcut: GlobalShortcut
    let onCapture: (GlobalShortcut) -> Void
    let onInvalidCapture: () -> Void

    func makeNSView(context: Context) -> ShortcutRecorderButton {
        let button = ShortcutRecorderButton()
        button.onCapture = onCapture
        button.onInvalidCapture = onInvalidCapture
        button.apply(shortcut)
        return button
    }

    func updateNSView(_ button: ShortcutRecorderButton, context: Context) {
        button.onCapture = onCapture
        button.onInvalidCapture = onInvalidCapture
        button.apply(shortcut)
    }
}

final class ShortcutRecorderButton: NSButton {
    var onCapture: ((GlobalShortcut) -> Void)?
    var onInvalidCapture: (() -> Void)?

    private var isRecording = false
    private var shortcutDisplay = ""

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        bezelStyle = .rounded
        controlSize = .regular
        font = .monospacedSystemFont(ofSize: 13, weight: .medium)
        setButtonType(.momentaryPushIn)
        target = self
        action = #selector(beginRecording)
        toolTip = "Click, then press your preferred key combination."
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { true }

    @objc private func beginRecording() {
        isRecording = true
        title = "Press keys…"
        window?.makeFirstResponder(self)
    }

    override func keyDown(with event: NSEvent) {
        guard isRecording else {
            super.keyDown(with: event)
            return
        }

        let modifiers = carbonModifiers(from: event.modifierFlags)
        guard GlobalShortcut(
            keyCode: UInt32(event.keyCode),
            modifiers: modifiers,
            keyDisplay: ""
        ).hasSafetyModifier else {
            NSSound.beep()
            title = "Use ⌘, ⌥, or ⌃"
            onInvalidCapture?()
            restoreTitleSoon()
            return
        }

        let captured = GlobalShortcut(
            keyCode: UInt32(event.keyCode),
            modifiers: modifiers,
            keyDisplay: displayName(for: event)
        )
        isRecording = false
        onCapture?(captured)
        window?.makeFirstResponder(nil)
    }

    override func resignFirstResponder() -> Bool {
        isRecording = false
        title = shortcutDisplay
        return super.resignFirstResponder()
    }

    func apply(_ shortcut: GlobalShortcut) {
        shortcutDisplay = shortcut.displayName
        guard !isRecording else { return }
        title = shortcutDisplay
    }

    private func restoreTitleSoon() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.1) { [weak self] in
            guard let self, self.isRecording else { return }
            self.title = self.shortcutDisplay
        }
    }

    private func carbonModifiers(from flags: NSEvent.ModifierFlags) -> UInt32 {
        let flags = flags.intersection(.deviceIndependentFlagsMask)
        var modifiers: UInt32 = 0
        if flags.contains(.control) { modifiers |= UInt32(controlKey) }
        if flags.contains(.option) { modifiers |= UInt32(optionKey) }
        if flags.contains(.shift) { modifiers |= UInt32(shiftKey) }
        if flags.contains(.command) { modifiers |= UInt32(cmdKey) }
        return modifiers
    }

    private func displayName(for event: NSEvent) -> String {
        switch Int(event.keyCode) {
        case Int(kVK_Return): return "↩"
        case Int(kVK_Tab): return "⇥"
        case Int(kVK_Space): return "Space"
        case Int(kVK_Delete): return "⌫"
        case Int(kVK_ForwardDelete): return "⌦"
        case Int(kVK_Escape): return "Esc"
        case Int(kVK_LeftArrow): return "←"
        case Int(kVK_RightArrow): return "→"
        case Int(kVK_UpArrow): return "↑"
        case Int(kVK_DownArrow): return "↓"
        default:
            return event.charactersIgnoringModifiers?.uppercased() ?? "Key"
        }
    }
}
