import Cocoa
import Carbon

// MARK: - F16 グローバルホットキー管理

final class HotkeyManager {
    private let appState: AppState
    fileprivate var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    fileprivate static let f16KeyCode: UInt16 = 106

    init(appState: AppState) {
        self.appState = appState
    }

    deinit {
        stop()
    }

    // MARK: - 開始/停止

    func start() {
        guard eventTap == nil else { return }

        let eventMask: CGEventMask = (1 << CGEventType.keyDown.rawValue)
        let unmanagedSelf = Unmanaged.passRetained(self)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: eventMask,
            callback: hotkeyCallback,
            userInfo: unmanagedSelf.toOpaque()
        ) else {
            unmanagedSelf.release()
            print("[HotkeyManager] CGEvent tapの作成に失敗。Accessibility権限を確認してください。")
            return
        }

        eventTap = tap
        runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)

        if let source = runLoopSource {
            CFRunLoopAddSource(CFRunLoopGetCurrent(), source, .commonModes)
            CGEvent.tapEnable(tap: tap, enable: true)
            print("[HotkeyManager] F16ホットキーの監視を開始")
        }
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
            if let source = runLoopSource {
                CFRunLoopRemoveSource(CFRunLoopGetCurrent(), source, .commonModes)
            }
            // passRetainedで増やした参照カウントを解放
            Unmanaged.passUnretained(self).release()
        }
        eventTap = nil
        runLoopSource = nil
    }

    fileprivate func handleHotkey() {
        DispatchQueue.main.async { [weak self] in
            self?.appState.toggleOverlay()
        }
    }
}

// MARK: - CGEvent コールバック

private func hotkeyCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    userInfo: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
        if let userInfo {
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userInfo).takeUnretainedValue()
            if let tap = manager.eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
            }
        }
        return Unmanaged.passUnretained(event)
    }

    guard type == .keyDown else {
        return Unmanaged.passUnretained(event)
    }

    let keyCode = UInt16(event.getIntegerValueField(.keyboardEventKeycode))

    if keyCode == HotkeyManager.f16KeyCode {
        if let userInfo {
            let manager = Unmanaged<HotkeyManager>.fromOpaque(userInfo).takeUnretainedValue()
            manager.handleHotkey()
        }
        return nil
    }

    return Unmanaged.passUnretained(event)
}
