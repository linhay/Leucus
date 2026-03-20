#if canImport(AppKit) && !canImport(UIKit)
import AppKit
import FolderCard
import InfiniteCanvasKit
import Testing
@testable import CanvasKit

@MainActor
struct CanvasKitTests {
  @Test
  func leucusUpdateFeedURLShouldAcceptValidHTTPAndHTTPS() {
    #expect(
      LeucusUpdateConfiguration.normalizedFeedURL(from: "https://example.com/appcast.xml")?
        .absoluteString == "https://example.com/appcast.xml"
    )
    #expect(
      LeucusUpdateConfiguration.normalizedFeedURL(from: "http://localhost:8000/appcast.xml")?
        .absoluteString == "http://localhost:8000/appcast.xml"
    )
  }

  @Test
  func leucusUpdateFeedURLShouldRejectInvalidOrUnsupportedSchemes() {
    #expect(LeucusUpdateConfiguration.normalizedFeedURL(from: nil) == nil)
    #expect(LeucusUpdateConfiguration.normalizedFeedURL(from: "") == nil)
    #expect(LeucusUpdateConfiguration.normalizedFeedURL(from: "   ") == nil)
    #expect(LeucusUpdateConfiguration.normalizedFeedURL(from: "ftp://example.com/feed.xml") == nil)
    #expect(LeucusUpdateConfiguration.normalizedFeedURL(from: "not-a-url") == nil)
  }

  @Test
  func leucusUpdateFeedURLShouldTrimWhitespace() {
    let url = LeucusUpdateConfiguration.normalizedFeedURL(
      from: "  https://example.com/leucus/appcast.xml  "
    )
    #expect(url?.absoluteString == "https://example.com/leucus/appcast.xml")
  }

  @Test
  func leucusUpdatePublicKeyShouldRequireNonEmptyValue() {
    #expect(
      !LeucusUpdateConfiguration.hasPublicKey(in: [:])
    )
    #expect(
      !LeucusUpdateConfiguration.hasPublicKey(in: [
        LeucusUpdateConfiguration.publicKeyInfoKey: "   ",
      ])
    )
    #expect(
      LeucusUpdateConfiguration.hasPublicKey(in: [
        LeucusUpdateConfiguration.publicKeyInfoKey: "AbCdEf123",
      ])
    )
  }

  @Test
  func alignButtonStyleShouldUseHighContrastPalette() {
    let button = NSButton(title: "对齐网格", target: nil, action: nil)
    CanvasAlignButtonStyle.apply(to: button)

    #expect(button.isBordered == false)
    #expect(button.layer?.borderWidth == 1)

    guard
      let backgroundCG = button.layer?.backgroundColor,
      let backgroundColor = NSColor(cgColor: backgroundCG),
      let textColor = button.attributedTitle.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor
    else {
      Issue.record("button style should provide both background and foreground colors")
      return
    }

    let ratio = contrastRatio(foreground: textColor, background: backgroundColor)
    #expect(ratio >= 4.5)
  }

  @Test
  @MainActor
  func detachFolderCardShouldMoveSameHostViewToNewWindow() {
    let workspace = CanvasWorkspaceView(frame: CGRect(x: 0, y: 0, width: 900, height: 700))
    let node = CanvasNodeCard.folder(
      at: .zero,
      workingDirectory: FileManager.default.homeDirectoryForCurrentUser.path,
      title: "Desktop"
    )
    workspace.canvasView.nodes = [node]
    workspace.layoutSubtreeIfNeeded()

    let window = NSWindow(
      contentRect: CGRect(x: 100, y: 100, width: 900, height: 700),
      styleMask: [.titled, .closable],
      backing: .buffered,
      defer: false
    )
    window.contentView = workspace
    defer {
      window.orderOut(nil)
      window.close()
    }
    workspace.layoutSubtreeIfNeeded()

    guard let hostBefore = firstFolderHostView(in: workspace) else {
      Issue.record("folder host view should exist before detach")
      return
    }
    let originalWindow = hostBefore.window

    let pointInView = CGPoint(x: 460, y: 360)
    let pointInWindow = workspace.canvasView.convert(pointInView, to: nil)
    guard
      let event = NSEvent.mouseEvent(
        with: .rightMouseDown,
        location: pointInWindow,
        modifierFlags: [],
        timestamp: 0,
        windowNumber: window.windowNumber,
        context: nil,
        eventNumber: 0,
        clickCount: 1,
        pressure: 1
      ),
      let menu = workspace.canvasView.menu(for: event),
      let index = menu.items.firstIndex(where: { $0.title == "展开为独立窗口" })
    else {
      Issue.record("detach menu item should be available")
      return
    }

    menu.performActionForItem(at: index)

    #expect(firstFolderHostView(in: workspace) == nil)
    #expect(hostBefore.window != nil)
    #expect(hostBefore.window !== originalWindow)
    #expect(hostBefore.window !== workspace.window)
  }

  private func firstFolderHostView(in root: NSView) -> FolderBrowserHostView? {
    if let host = root as? FolderBrowserHostView {
      return host
    }
    for child in root.subviews {
      if let host = firstFolderHostView(in: child) {
        return host
      }
    }
    return nil
  }

  private func contrastRatio(foreground: NSColor, background: NSColor) -> Double {
    let fg = foreground.usingColorSpace(.deviceRGB) ?? foreground
    let bg = background.usingColorSpace(.deviceRGB) ?? background
    let l1 = relativeLuminance(red: Double(fg.redComponent), green: Double(fg.greenComponent), blue: Double(fg.blueComponent))
    let l2 = relativeLuminance(red: Double(bg.redComponent), green: Double(bg.greenComponent), blue: Double(bg.blueComponent))
    let lighter = max(l1, l2)
    let darker = min(l1, l2)
    return (lighter + 0.05) / (darker + 0.05)
  }

  private func relativeLuminance(red: Double, green: Double, blue: Double) -> Double {
    0.2126 * linearized(red) + 0.7152 * linearized(green) + 0.0722 * linearized(blue)
  }

  private func linearized(_ value: Double) -> Double {
    if value <= 0.03928 {
      return value / 12.92
    }
    return pow((value + 0.055) / 1.055, 2.4)
  }
}
#endif
