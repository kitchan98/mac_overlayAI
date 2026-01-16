import SwiftUI
import HotKey

@main
struct TextAssistantApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        MenuBarExtra("Text Assistant", systemImage: "text.bubble") {
            MenuBarView(openSettings: {
                AppDelegate.shared?.openSettings()
            })
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    static var shared: AppDelegate?

    private var hotkeyManager: HotkeyManager?
    private var overlayManager: OverlayManager?
    private var settingsWindow: NSWindow?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self

        // Initialize managers
        overlayManager = OverlayManager.shared
        hotkeyManager = HotkeyManager.shared

        // Set up hotkey callback
        hotkeyManager?.onHotkeyTriggered = { [weak self] in
            self?.handleHotkey()
        }

        // Check accessibility permission
        TextCaptureService.shared.requestAccessibilityPermission()
    }

    private func handleHotkey() {
        let selectedText = TextCaptureService.shared.getSelectedText() ?? ""

        DispatchQueue.main.async {
            OverlayManager.shared.show(with: selectedText.isEmpty ? nil : selectedText)
        }
    }

    func openSettings() {
        if settingsWindow == nil {
            let settingsView = SettingsView()
            let hostingController = NSHostingController(rootView: settingsView)

            let window = NSWindow(contentViewController: hostingController)
            window.title = "Text Assistant Settings"
            window.styleMask = [.titled, .closable, .miniaturizable]
            window.setContentSize(NSSize(width: 450, height: 400))
            window.center()
            window.isReleasedWhenClosed = false

            settingsWindow = window
        }

        NSApp.setActivationPolicy(.regular)
        settingsWindow?.makeKeyAndOrderFront(nil)
        settingsWindow?.makeFirstResponder(settingsWindow?.contentView)
        NSApp.activate(ignoringOtherApps: true)
    }
}
