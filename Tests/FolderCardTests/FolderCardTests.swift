#if canImport(AppKit) && !canImport(UIKit)
import AppKit
import Foundation
import Testing
@testable import FolderCard

@MainActor
struct FolderCardTests {
  @Test
  func browserUsesReadableHighContrastTheme() throws {
    let tempRoot = FileManager.default.temporaryDirectory
      .appendingPathComponent("folder-card-test-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: tempRoot, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: tempRoot) }

    let fileURL = tempRoot.appendingPathComponent("demo.txt")
    try "hello".write(to: fileURL, atomically: true, encoding: .utf8)

    let sut = FolderBrowserHostView(directoryPath: tempRoot.path)
    sut.frame = CGRect(x: 0, y: 0, width: 640, height: 420)
    sut.layoutSubtreeIfNeeded()

    #expect(sut.layer?.backgroundColor == FolderBrowserTheme.panelBackground.cgColor)

    guard let scrollView = sut.subviews.first(where: { $0 is NSScrollView }) as? NSScrollView else {
      Issue.record("scroll view should exist")
      return
    }

    #expect(scrollView.drawsBackground)
    #expect(scrollView.backgroundColor == FolderBrowserTheme.listBackground)

    guard let tableView = scrollView.documentView as? NSTableView else {
      Issue.record("table view should exist")
      return
    }

    #expect(tableView.backgroundColor == FolderBrowserTheme.listBackground)
    #expect(tableView.numberOfRows > 0)

    guard
      let cell = tableView.view(atColumn: 0, row: 0, makeIfNecessary: true) as? NSTableCellView,
      let textColor = cell.textField?.textColor
    else {
      Issue.record("cell text color should be available")
      return
    }

    let ratio = contrastRatio(foreground: textColor, background: FolderBrowserTheme.listBackground)
    #expect(ratio >= 7.0)
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
