#if canImport(AppKit) && !canImport(UIKit)
import AppKit

public enum FolderBrowserTheme {
  public static let panelBackground = NSColor(
    calibratedRed: 0.10,
    green: 0.11,
    blue: 0.13,
    alpha: 1
  )
  public static let toolbarBackground = NSColor(
    calibratedRed: 0.17,
    green: 0.18,
    blue: 0.20,
    alpha: 1
  )
  public static let listBackground = NSColor(
    calibratedRed: 0.08,
    green: 0.09,
    blue: 0.11,
    alpha: 1
  )
  public static let primaryText = NSColor(
    calibratedRed: 0.94,
    green: 0.95,
    blue: 0.97,
    alpha: 1
  )
  public static let secondaryText = NSColor(
    calibratedRed: 0.79,
    green: 0.82,
    blue: 0.87,
    alpha: 1
  )
  public static let iconTint = NSColor(
    calibratedRed: 0.85,
    green: 0.88,
    blue: 0.93,
    alpha: 1
  )
  public static let selectionBackground = NSColor(
    calibratedRed: 0.20,
    green: 0.34,
    blue: 0.62,
    alpha: 0.92
  )
}
#endif
