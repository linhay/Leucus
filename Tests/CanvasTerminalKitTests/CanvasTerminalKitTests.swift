import Testing
@testable import CanvasTerminalKit

struct CanvasTerminalKitTests {
  @Test
  func resetSkeletonExposesVersionMarker() {
    #expect(CanvasTerminalKit.version == "0.1.0-reset")
  }
}
