import AppKit
import SwiftUI

final class FloatingPanel: NSPanel {
    init(contentRect: NSRect, content: some View) {
        super.init(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .titled, .closable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        // Panel configuration
        self.level = .floating
        self.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        self.isMovableByWindowBackground = true
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = true
        self.titleVisibility = .hidden
        self.titlebarAppearsTransparent = true

        // Don't activate app when showing
        self.hidesOnDeactivate = false
        self.becomesKeyOnlyIfNeeded = true

        // Set minimum size
        self.minSize = NSSize(width: 350, height: 250)
        self.maxSize = NSSize(width: 600, height: 800)

        // Set SwiftUI content
        let hostingView = NSHostingView(rootView: content)
        self.contentView = hostingView
    }

    override var canBecomeKey: Bool { true }

    override func keyDown(with event: NSEvent) {
        // Close on Escape key
        if event.keyCode == 53 {
            close()
        } else {
            super.keyDown(with: event)
        }
    }
}
