import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let defaultContentSize = NSSize(width: 1200, height: 820)
    private let minimumContentSize = NSSize(width: 640, height: 420)
    private var window: NSWindow?

    func applicationDidFinishLaunching(_: Notification) {
        createOrShowWindow()
    }

    func applicationDidBecomeActive(_: Notification) {
        guard !NSApp.windows.contains(where: \.isVisible) else { return }
        createOrShowWindow()
    }

    func applicationShouldHandleReopen(_: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            createOrShowWindow()
            return false
        }
        return true
    }

    func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
        false
    }

    private func createOrShowWindow() {
        if let window {
            if window.isMiniaturized {
                window.deminiaturize(nil)
            }
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }

        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: defaultContentSize),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )
        window.title = "CanvasTerminal Example"
        window.contentViewController = ViewController()
        window.contentMinSize = minimumContentSize
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        repairRestoredWindowSizeIfNeeded(window)
        self.window = window
    }

    private func repairRestoredWindowSizeIfNeeded(_ window: NSWindow) {
        DispatchQueue.main.async { [defaultContentSize, minimumContentSize] in
            let contentRect = window.contentRect(forFrameRect: window.frame)
            guard contentRect.width < minimumContentSize.width || contentRect.height < minimumContentSize.height
            else {
                return
            }

            window.setContentSize(defaultContentSize)
            window.center()
        }
    }
}
