#if canImport(AppKit) && !canImport(UIKit)
import AppKit
import Testing
@testable import WebCard

@MainActor
struct WebCardTests {
  @Test
  func simpleWebCardShouldPreserveTitleAndURL() {
    let sut = SimpleWebCard(
      options: SimpleWebCardOptions(
        webURL: "https://example.com",
        title: "Example"
      )
    )

    #expect(sut.title == "Example")
    #expect(sut.url?.absoluteString == "https://example.com")
  }

  @Test
  func hostViewShouldCreateWebView() {
    let card = SimpleWebCard(
      options: SimpleWebCardOptions(
        webURL: nil,
        title: "Docs"
      )
    )
    let host = SimpleWebCardHostView(card: card)
    host.frame = CGRect(x: 0, y: 0, width: 640, height: 420)
    host.layoutSubtreeIfNeeded()

    #expect(host.webView.superview === host)
  }
}
#endif
