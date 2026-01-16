import Foundation
import AppKit
import HotKey
import Carbon

final class HotkeyManager {
    static let shared = HotkeyManager()

    private var hotKey: HotKey?
    var onHotkeyTriggered: (() -> Void)?

    private init() {
        registerHotkey()
    }

    private func registerHotkey() {
        // Cmd+Option+A
        hotKey = HotKey(key: .a, modifiers: [.command, .option])

        hotKey?.keyDownHandler = { [weak self] in
            self?.onHotkeyTriggered?()
        }
    }

    func updateHotkey(key: Key, modifiers: NSEvent.ModifierFlags) {
        hotKey = HotKey(key: key, modifiers: modifiers)
        hotKey?.keyDownHandler = { [weak self] in
            self?.onHotkeyTriggered?()
        }
    }
}
