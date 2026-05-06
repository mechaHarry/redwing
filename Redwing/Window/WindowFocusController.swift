import AppKit

enum WindowFocusController {
    static func centeredFrame(windowSize: CGSize, visibleFrame: CGRect) -> CGRect {
        let width = min(windowSize.width, visibleFrame.width)
        let height = min(windowSize.height, visibleFrame.height)
        let x = visibleFrame.origin.x + ((visibleFrame.width - width) / 2)
        let y = visibleFrame.origin.y + ((visibleFrame.height - height) / 2)

        return CGRect(x: x, y: y, width: width, height: height)
    }

    @MainActor
    static func moveToCurrentDesktop(window: NSWindow?) {
        guard let window else { return }

        guard let screen = NSScreen.main ?? window.screen ?? NSScreen.screens.first else {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let visibleFrame = screen.visibleFrame
        guard !visibleFrame.isEmpty else {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let currentSize = window.frame.size
        let windowSize = currentSize == .zero ? CGSize(width: 1100, height: 720) : currentSize
        let frame = centeredFrame(windowSize: windowSize, visibleFrame: visibleFrame)

        window.setFrame(frame, display: true)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
