import AppKit
import SwiftUI

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
            orderFrontOnCurrentDesktop(window)
            return
        }

        let visibleFrame = screen.visibleFrame
        guard !visibleFrame.isEmpty else {
            orderFrontOnCurrentDesktop(window)
            return
        }

        let currentSize = window.frame.size
        let windowSize = currentSize == .zero ? CGSize(width: 1100, height: 720) : currentSize
        let frame = centeredFrame(windowSize: windowSize, visibleFrame: visibleFrame)

        window.setFrame(frame, display: true)
        orderFrontOnCurrentDesktop(window)
    }

    static func collectionBehaviorForCurrentDesktop(
        from behavior: NSWindow.CollectionBehavior
    ) -> NSWindow.CollectionBehavior {
        var updated = behavior
        updated.insert(.moveToActiveSpace)
        return updated
    }

    @MainActor
    private static func orderFrontOnCurrentDesktop(_ window: NSWindow) {
        let previousBehavior = window.collectionBehavior
        window.collectionBehavior = collectionBehaviorForCurrentDesktop(from: previousBehavior)
        defer { window.collectionBehavior = previousBehavior }

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

struct WindowFocusAttachment: NSViewRepresentable {
    let requestID: Int

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeNSView(context: Context) -> FocusView {
        FocusView()
    }

    func updateNSView(_ nsView: FocusView, context: Context) {
        context.coordinator.requestID = requestID
        nsView.onWindowAvailable = { window in
            Task { @MainActor in
                context.coordinator.focus(window: window)
            }
        }

        Task { @MainActor in
            context.coordinator.focus(window: nsView.window)
        }
    }

    final class Coordinator {
        var requestID = 0
        private var handledRequestID = 0

        @MainActor
        func focus(window: NSWindow?) {
            guard requestID > 0,
                  handledRequestID != requestID,
                  let window else {
                return
            }

            handledRequestID = requestID
            WindowFocusController.moveToCurrentDesktop(window: window)
        }
    }

    final class FocusView: NSView {
        var onWindowAvailable: ((NSWindow?) -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            onWindowAvailable?(window)
        }
    }
}
