import AppKit

@MainActor
final class OnevcatCustomShortcutRegistry {
  static let shared = OnevcatCustomShortcutRegistry()

  private init() {}

  func matches(event: NSEvent) -> Bool {
    false
  }
}
