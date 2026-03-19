import Testing
@testable import CanvasTerminalKit

struct CanvasTerminalKitTests {
  @Test
  func versionIsUpdatedForGhosttyIntegration() {
    #expect(CanvasTerminalKit.version == "0.2.4")
  }

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
}
