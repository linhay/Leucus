import AppKit
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

  @Test
  func terminalScrollRoutesToCanvasWhenNoScrollableRange() {
    let state = GhosttyScrollWheelRouting.ScrollbarState(total: 20, offset: 0, length: 20)

    #expect(
      GhosttyScrollWheelRouting.shouldPassthroughToCanvas(
        deltaX: 0,
        deltaY: 12,
        scrollbar: state
      )
    )
    #expect(
      GhosttyScrollWheelRouting.shouldPassthroughToCanvas(
        deltaX: 0,
        deltaY: -12,
        scrollbar: state
      )
    )
  }

  @Test
  func terminalScrollRoutesToCanvasOnlyAtMatchingBoundary() {
    let top = GhosttyScrollWheelRouting.ScrollbarState(total: 100, offset: 0, length: 20)
    #expect(
      GhosttyScrollWheelRouting.shouldPassthroughToCanvas(
        deltaX: 0,
        deltaY: 10,
        scrollbar: top
      )
    )
    #expect(
      !GhosttyScrollWheelRouting.shouldPassthroughToCanvas(
        deltaX: 0,
        deltaY: -10,
        scrollbar: top
      )
    )

    let bottom = GhosttyScrollWheelRouting.ScrollbarState(total: 100, offset: 80, length: 20)
    #expect(
      GhosttyScrollWheelRouting.shouldPassthroughToCanvas(
        deltaX: 0,
        deltaY: -10,
        scrollbar: bottom
      )
    )
    #expect(
      !GhosttyScrollWheelRouting.shouldPassthroughToCanvas(
        deltaX: 0,
        deltaY: 10,
        scrollbar: bottom
      )
    )
  }

  @Test
  func terminalScrollStaysInTerminalWhenScrollableAndNotAtBoundary() {
    let middle = GhosttyScrollWheelRouting.ScrollbarState(total: 100, offset: 50, length: 20)

    #expect(
      !GhosttyScrollWheelRouting.shouldPassthroughToCanvas(
        deltaX: 0,
        deltaY: 10,
        scrollbar: middle
      )
    )
    #expect(
      !GhosttyScrollWheelRouting.shouldPassthroughToCanvas(
        deltaX: 0,
        deltaY: -10,
        scrollbar: middle
      )
    )
  }

  @Test
  func terminalHorizontalScrollRoutesToCanvas() {
    let middle = GhosttyScrollWheelRouting.ScrollbarState(total: 100, offset: 50, length: 20)

    #expect(
      GhosttyScrollWheelRouting.shouldPassthroughToCanvas(
        deltaX: 12,
        deltaY: 2,
        scrollbar: middle
      )
    )
  }

  @Test
  func terminalCommandScrollAlwaysRoutesToCanvas() {
    let middle = GhosttyScrollWheelRouting.ScrollbarState(total: 100, offset: 50, length: 20)

    #expect(
      GhosttyScrollWheelRouting.shouldPassthroughToCanvas(
        modifierFlags: [.command],
        deltaX: 0,
        deltaY: 10,
        scrollbar: middle
      )
    )
    #expect(
      GhosttyScrollWheelRouting.shouldPassthroughToCanvas(
        modifierFlags: [.command],
        deltaX: 0,
        deltaY: -10,
        scrollbar: middle
      )
    )
  }

  @Test
  func terminalScrollReachingBoundaryWithinSameGestureShouldNotRouteCanvas() {
    let top = GhosttyScrollWheelRouting.ScrollbarState(total: 100, offset: 0, length: 20)
    #expect(
      !GhosttyScrollWheelRouting.shouldPassthroughToCanvas(
        deltaX: 0,
        deltaY: 10,
        scrollbar: top,
        terminalConsumedInGesture: true
      )
    )

    let bottom = GhosttyScrollWheelRouting.ScrollbarState(total: 100, offset: 80, length: 20)
    #expect(
      !GhosttyScrollWheelRouting.shouldPassthroughToCanvas(
        deltaX: 0,
        deltaY: -10,
        scrollbar: bottom,
        terminalConsumedInGesture: true
      )
    )
  }
}
