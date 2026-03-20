import Testing
@testable import TerminalCard

struct TerminalCardTests {
  @Test
  @MainActor
  func simpleTerminalAppliesProvidedOptions() {
    let sut = SimpleTerminal(
      options: .init(
        workingDirectory: "/tmp/canvas-terminal",
        fontSize: 14,
        title: "Demo"
      )
    )

    #expect(sut.title == "Demo")
    #expect(sut.state.configuration.workingDirectory == "/tmp/canvas-terminal")
    #expect(sut.state.configuration.fontSize == 14)

    switch sut.state.configuration.backend {
    case .exec:
      #expect(Bool(true))
    case .inMemory:
      #expect(Bool(false))
    }
  }

  #if canImport(AppKit) && !canImport(UIKit)
  @Test
  @MainActor
  func simpleTerminalSharesGhosttyRuntime() {
    let a = SimpleTerminal(options: .init(title: "A"))
    let b = SimpleTerminal(options: .init(title: "B"))

    #expect(a.runtime === b.runtime)
  }
  #endif
}
