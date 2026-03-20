#if canImport(AppKit) && !canImport(UIKit)
import AppKit

enum CanvasAlignButtonStyle {
  static let backgroundColor = NSColor(calibratedRed: 0.15, green: 0.18, blue: 0.24, alpha: 0.96)
  static let titleColor = NSColor.white
  static let borderColor = NSColor(calibratedWhite: 1.0, alpha: 0.28)
  static let shadowColor = NSColor(calibratedWhite: 0.0, alpha: 0.32)

  @MainActor
  static func apply(to button: NSButton) {
    button.isBordered = false
    button.bezelStyle = .regularSquare
    button.wantsLayer = true
    button.contentTintColor = titleColor
    button.focusRingType = .none

    button.layer?.backgroundColor = backgroundColor.cgColor
    button.layer?.borderColor = borderColor.cgColor
    button.layer?.borderWidth = 1
    button.layer?.cornerRadius = 10
    button.layer?.masksToBounds = false
    button.layer?.shadowColor = shadowColor.cgColor
    button.layer?.shadowOpacity = 1
    button.layer?.shadowRadius = 8
    button.layer?.shadowOffset = CGSize(width: 0, height: -1)

    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    button.attributedTitle = NSAttributedString(
      string: button.title,
      attributes: [
        .foregroundColor: titleColor,
        .font: NSFont.systemFont(ofSize: 12, weight: .semibold),
        .paragraphStyle: paragraph,
      ]
    )
  }
}
#endif
