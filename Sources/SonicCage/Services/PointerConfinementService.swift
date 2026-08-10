import ApplicationServices
import CoreGraphics
import Foundation

/// A narrow Core Graphics bridge that recentres the pointer before it reaches
/// a display edge while preserving the mouse movement event for the game.
final class PointerConfinementService {
    struct Margins: Equatable {
        var top: CGFloat
        var leading: CGFloat
        var bottom: CGFloat
        var trailing: CGFloat
    }

    private static let handledEventTypes: [CGEventType] = [
        .mouseMoved,
        .leftMouseDragged,
        .rightMouseDragged,
        .otherMouseDragged
    ]

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var margins = Margins(top: 2, leading: 2, bottom: 16, trailing: 2)
    private var keepsOneDisplay = true
    private var pinnedDisplay: CGDirectDisplayID?

    private(set) var isActive = false

    /// Probe the actual capability SonicCage uses without installing a
    /// persistent tap. This guards against a stale AX status response on
    /// locally development-signed builds.
    static func canControlPointer() -> Bool {
        let mouseMovedMask = CGEventMask(1) << CGEventMask(CGEventType.mouseMoved.rawValue)
        guard let probe = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mouseMovedMask,
            callback: permissionProbeEventCallback,
            userInfo: nil
        ) else {
            return false
        }
        CFMachPortInvalidate(probe)
        return true
    }

    deinit {
        stop()
    }

    func update(margins: Margins, keepsOneDisplay: Bool) {
        self.margins = margins
        self.keepsOneDisplay = keepsOneDisplay
        if !keepsOneDisplay {
            pinnedDisplay = nil
        }
    }

    func start() -> Bool {
        guard !isActive else { return true }

        let mask = Self.handledEventTypes.reduce(CGEventMask(0)) { partialResult, type in
            partialResult | (CGEventMask(1) << CGEventMask(type.rawValue))
        }

        guard let newTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: pointerEventCallback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            return false
        }

        eventTap = newTap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, newTap, 0)
        runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: newTap, enable: true)

        if keepsOneDisplay, let pointer = CGEvent(source: nil)?.location {
            pinnedDisplay = Self.display(containing: pointer)
        }
        isActive = true
        return true
    }

    func stop() {
        guard let eventTap else {
            isActive = false
            pinnedDisplay = nil
            return
        }

        CGEvent.tapEnable(tap: eventTap, enable: false)
        if let runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), runLoopSource, .commonModes)
        }
        CFMachPortInvalidate(eventTap)
        self.eventTap = nil
        runLoopSource = nil
        pinnedDisplay = nil
        isActive = false
    }

    fileprivate func handle(_ type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if isActive, let eventTap {
                CGEvent.tapEnable(tap: eventTap, enable: true)
            }
            return Unmanaged.passUnretained(event)
        }

        guard isActive, Self.handledEventTypes.contains(type) else {
            return Unmanaged.passUnretained(event)
        }

        let pointer = event.location
        let display = pinnedDisplay ?? Self.display(containing: pointer) ?? CGMainDisplayID()
        let bounds = CGDisplayBounds(display)
        let safeRect = Self.safeRect(in: bounds, margins: margins)
        let cagedPoint = CGPoint(
            x: min(max(pointer.x, safeRect.minX), safeRect.maxX),
            y: min(max(pointer.y, safeRect.minY), safeRect.maxY)
        )

        guard cagedPoint != pointer else {
            return Unmanaged.passUnretained(event)
        }

        // Do not discard this event: Sonic uses its movement delta to turn the
        // camera. Dropping it made the camera stop whenever the pointer met an
        // edge. Recentring preserves room for continued motion while returning
        // the same delta-bearing event to the game and to macOS.
        let recoveryPoint = Self.recoveryPoint(for: pointer, in: safeRect)
        CGWarpMouseCursorPosition(recoveryPoint)
        event.location = recoveryPoint
        return Unmanaged.passUnretained(event)
    }

    private static func safeRect(in bounds: CGRect, margins: Margins) -> CGRect {
        let horizontal = min(max(0, margins.leading + margins.trailing), max(0, bounds.width - 1))
        let vertical = min(max(0, margins.top + margins.bottom), max(0, bounds.height - 1))
        return CGRect(
            x: bounds.minX + min(max(0, margins.leading), horizontal),
            y: bounds.minY + min(max(0, margins.top), vertical),
            width: max(1, bounds.width - horizontal),
            height: max(1, bounds.height - vertical)
        )
    }

    private static func recoveryPoint(for pointer: CGPoint, in safeRect: CGRect) -> CGPoint {
        CGPoint(
            x: pointer.x < safeRect.minX || pointer.x > safeRect.maxX
                ? safeRect.midX
                : min(max(pointer.x, safeRect.minX), safeRect.maxX),
            y: pointer.y < safeRect.minY || pointer.y > safeRect.maxY
                ? safeRect.midY
                : min(max(pointer.y, safeRect.minY), safeRect.maxY)
        )
    }

    private static func display(containing point: CGPoint) -> CGDirectDisplayID? {
        var count: UInt32 = 0
        guard CGGetActiveDisplayList(0, nil, &count) == .success, count > 0 else { return nil }
        var displays = Array(repeating: CGDirectDisplayID(), count: Int(count))
        guard CGGetActiveDisplayList(count, &displays, &count) == .success else { return nil }
        return displays.prefix(Int(count)).first { CGDisplayBounds($0).contains(point) }
    }
}

private let pointerEventCallback: CGEventTapCallBack = { _, type, event, userInfo in
    guard let userInfo else { return nil }
    let service = Unmanaged<PointerConfinementService>.fromOpaque(userInfo).takeUnretainedValue()
    return service.handle(type, event: event)
}

private let permissionProbeEventCallback: CGEventTapCallBack = { _, _, event, _ in
    Unmanaged.passUnretained(event)
}
