import AppKit
import SwiftUI

@MainActor
final class OverlayManager {
    static let shared = OverlayManager()

    private var panel: FloatingPanel?
    private var viewModel: ChatViewModel?

    private init() {}

    func show(with selectedText: String?) {
        // Close existing panel if any
        hide()

        // Create new view model
        let vm = ChatViewModel()
        vm.startConversation(with: nil)  // Start empty conversation
        self.viewModel = vm

        // Create overlay view with selected text in input bar
        let overlayView = OverlayView(viewModel: vm, initialText: selectedText) { [weak self] in
            self?.hide()
        }

        // Calculate position near cursor
        let mouseLocation = NSEvent.mouseLocation
        let panelSize = NSSize(width: 400, height: 450)
        let origin = calculatePosition(for: panelSize, near: mouseLocation)

        // Create panel
        let contentRect = NSRect(origin: origin, size: panelSize)
        panel = FloatingPanel(contentRect: contentRect, content: overlayView)

        // Show panel
        panel?.makeKeyAndOrderFront(nil)
    }

    func hide() {
        panel?.close()
        panel = nil
        viewModel = nil
    }

    var isVisible: Bool {
        panel?.isVisible ?? false
    }

    private func calculatePosition(for size: NSSize, near point: NSPoint) -> NSPoint {
        guard let screen = NSScreen.main else {
            return point
        }

        let screenFrame = screen.visibleFrame
        var origin = point

        // Offset from cursor
        origin.x += 20
        origin.y -= size.height + 20

        // Keep within screen bounds (horizontal)
        if origin.x + size.width > screenFrame.maxX {
            origin.x = screenFrame.maxX - size.width - 10
        }
        if origin.x < screenFrame.minX {
            origin.x = screenFrame.minX + 10
        }

        // Keep within screen bounds (vertical)
        if origin.y < screenFrame.minY {
            origin.y = screenFrame.minY + 10
        }
        if origin.y + size.height > screenFrame.maxY {
            origin.y = screenFrame.maxY - size.height - 10
        }

        return origin
    }
}
