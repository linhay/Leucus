import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private let defaultContentSize = NSSize(width: 1200, height: 820)
    private let minimumContentSize = NSSize(width: 640, height: 420)
    private var window: NSWindow?
    private let updater = LeucusUpdater()
    private weak var checkForUpdatesMenuItem: NSMenuItem?

    func applicationDidFinishLaunching(_: Notification) {
        configureMainMenu()
        updater.startIfConfigured(infoDictionary: Bundle.main.infoDictionary ?? [:])
        refreshCheckForUpdatesMenuState()
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

    @objc
    private func checkForUpdates(_: Any?) {
        updater.checkForUpdates()
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
        window.title = "Leucus"
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

    private func configureMainMenu() {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)

        let appMenu = NSMenu(title: "Leucus")
        appMenuItem.submenu = appMenu

        appMenu.addItem(
            withTitle: "关于 Leucus",
            action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
            keyEquivalent: ""
        )
        appMenu.addItem(.separator())

        let updateItem = NSMenuItem(
            title: "检查更新…",
            action: #selector(checkForUpdates(_:)),
            keyEquivalent: "u"
        )
        updateItem.keyEquivalentModifierMask = [.command, .option]
        updateItem.target = self
        appMenu.addItem(updateItem)
        checkForUpdatesMenuItem = updateItem

        appMenu.addItem(.separator())
        appMenu.addItem(
            withTitle: "隐藏 Leucus",
            action: #selector(NSApplication.hide(_:)),
            keyEquivalent: "h"
        )
        appMenu.addItem(
            withTitle: "隐藏其他",
            action: #selector(NSApplication.hideOtherApplications(_:)),
            keyEquivalent: "h"
        ).keyEquivalentModifierMask = [.command, .option]
        appMenu.addItem(
            withTitle: "显示全部",
            action: #selector(NSApplication.unhideAllApplications(_:)),
            keyEquivalent: ""
        )
        appMenu.addItem(.separator())
        appMenu.addItem(
            withTitle: "退出 Leucus",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )

        NSApp.mainMenu = mainMenu
    }

    private func refreshCheckForUpdatesMenuState() {
        checkForUpdatesMenuItem?.isEnabled = updater.isConfigured
    }
}
