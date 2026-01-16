import Foundation
import AppKit
import ApplicationServices

final class TextCaptureService {
    static let shared = TextCaptureService()

    private init() {}

    /// Request accessibility permission from the user
    func requestAccessibilityPermission() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        AXIsProcessTrustedWithOptions(options)
    }

    /// Check if accessibility permission is granted
    var hasAccessibilityPermission: Bool {
        AXIsProcessTrusted()
    }

    /// Get selected text from the frontmost application
    func getSelectedText() -> String? {
        // Try Accessibility API first
        if let text = getSelectedTextViaAccessibility(), !text.isEmpty {
            return text
        }

        // Fallback to clipboard simulation
        return getSelectedTextViaClipboard()
    }

    /// Get selected text using macOS Accessibility API
    private func getSelectedTextViaAccessibility() -> String? {
        guard hasAccessibilityPermission else { return nil }

        let systemWideElement = AXUIElementCreateSystemWide()

        var focusedApp: CFTypeRef?
        let appResult = AXUIElementCopyAttributeValue(
            systemWideElement,
            kAXFocusedApplicationAttribute as CFString,
            &focusedApp
        )

        guard appResult == .success, let app = focusedApp else { return nil }

        var focusedElement: CFTypeRef?
        let elementResult = AXUIElementCopyAttributeValue(
            app as! AXUIElement,
            kAXFocusedUIElementAttribute as CFString,
            &focusedElement
        )

        guard elementResult == .success, let element = focusedElement else { return nil }

        var selectedText: CFTypeRef?
        let textResult = AXUIElementCopyAttributeValue(
            element as! AXUIElement,
            kAXSelectedTextAttribute as CFString,
            &selectedText
        )

        guard textResult == .success else { return nil }

        return selectedText as? String
    }

    /// Get selected text by simulating Cmd+C and reading clipboard
    private func getSelectedTextViaClipboard() -> String? {
        let pasteboard = NSPasteboard.general

        // Save current clipboard content
        let previousContent = pasteboard.string(forType: .string)
        let previousChangeCount = pasteboard.changeCount

        // Simulate Cmd+C
        simulateCopy()

        // Wait for clipboard update
        usleep(100_000) // 100ms

        // Check if clipboard changed
        guard pasteboard.changeCount != previousChangeCount else {
            return nil
        }

        let selectedText = pasteboard.string(forType: .string)

        // Restore previous clipboard (optional - comment out to keep copied text)
        if let previous = previousContent, previous != selectedText {
            pasteboard.clearContents()
            pasteboard.setString(previous, forType: .string)
        }

        return selectedText
    }

    /// Simulate Cmd+C keystroke
    private func simulateCopy() {
        let source = CGEventSource(stateID: .hidSystemState)

        // Key code for 'C' is 8
        let keyDown = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: true)
        keyDown?.flags = .maskCommand

        let keyUp = CGEvent(keyboardEventSource: source, virtualKey: 0x08, keyDown: false)
        keyUp?.flags = .maskCommand

        keyDown?.post(tap: .cghidEventTap)
        keyUp?.post(tap: .cghidEventTap)
    }
}
