import Foundation
import SwiftUI

public enum WebCardInfo {
  public static let version = "0.1.0"
}

public struct SimpleWebCardOptions: Sendable, Equatable {
  public var webURL: String?
  public var title: String

  public init(
    webURL: String? = nil,
    title: String = "Web"
  ) {
    self.webURL = webURL
    self.title = title
  }
}

@MainActor
public final class SimpleWebCard {
  public let title: String
  public private(set) var url: URL?

  public init(options: SimpleWebCardOptions = .init()) {
    title = options.title
    url = SimpleWebCard.resolvedURL(from: options.webURL)
  }

  static func resolvedURL(from raw: String?) -> URL? {
    guard let raw, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
      return nil
    }
    let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
    if let url = URL(string: trimmed), let scheme = url.scheme, !scheme.isEmpty {
      return url
    }
    return URL(string: "https://\(trimmed)")
  }

  public func setURL(from raw: String?) {
    url = Self.resolvedURL(from: raw)
  }
}

@MainActor
@available(macOS 14.0, iOS 17.0, macCatalyst 17.0, *)
public struct SimpleWebCardView: View {
  private let card: SimpleWebCard

  public init(card: SimpleWebCard? = nil) {
    self.card = card ?? .init()
  }

  public var body: some View {
    SimpleWebCardPlatformView(card: card)
      .background(.clear)
  }
}

#if canImport(AppKit) && !canImport(UIKit)
import AppKit
import WebKit

@MainActor
@available(macOS 14.0, *)
public final class SimpleWebCardHostView: NSView {
  public let card: SimpleWebCard
  public let webView: WKWebView
  private var loadedURL: URL?
  public var onInteraction: (() -> Void)?
  public var onScrollWheelPassthrough: ((NSEvent) -> Void)?
  public var onMagnifyPassthrough: ((NSEvent) -> Void)?

  public init(card: SimpleWebCard? = nil) {
    let resolvedCard = card ?? .init()
    self.card = resolvedCard
    webView = WKWebView(frame: .zero)

    super.init(frame: .zero)
    wantsLayer = true
    layer?.masksToBounds = true
    addSubview(webView)

    loadIfNeeded(resolvedCard.url)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    nil
  }

  public override func layout() {
    super.layout()
    webView.frame = bounds
  }

  public func setURL(_ raw: String?) {
    card.setURL(from: raw)
    loadIfNeeded(card.url)
  }

  public override func mouseDown(with event: NSEvent) {
    onInteraction?()
    super.mouseDown(with: event)
  }

  public override func rightMouseDown(with event: NSEvent) {
    onInteraction?()
    super.rightMouseDown(with: event)
  }

  public override func scrollWheel(with event: NSEvent) {
    if event.modifierFlags.contains(.command), let onScrollWheelPassthrough {
      onScrollWheelPassthrough(event)
      return
    }
    super.scrollWheel(with: event)
  }

  public override func magnify(with event: NSEvent) {
    if let onMagnifyPassthrough {
      onMagnifyPassthrough(event)
      return
    }
    super.magnify(with: event)
  }

  private func loadIfNeeded(_ url: URL?) {
    guard let url else { return }
    guard loadedURL != url else { return }
    loadedURL = url
    webView.load(URLRequest(url: url))
  }
}

@MainActor
@available(macOS 14.0, *)
private struct SimpleWebCardPlatformView: NSViewRepresentable {
  let card: SimpleWebCard

  func makeNSView(context _: Context) -> SimpleWebCardHostView {
    SimpleWebCardHostView(card: card)
  }

  func updateNSView(_: SimpleWebCardHostView, context _: Context) {}
}
#elseif canImport(UIKit)
import UIKit
import WebKit

@MainActor
@available(iOS 17.0, macCatalyst 17.0, *)
private struct SimpleWebCardPlatformView: UIViewRepresentable {
  let card: SimpleWebCard

  func makeUIView(context _: Context) -> WKWebView {
    let webView = WKWebView(frame: .zero)
    if let url = card.url {
      webView.load(URLRequest(url: url))
    }
    return webView
  }

  func updateUIView(_: WKWebView, context _: Context) {}
}
#endif
