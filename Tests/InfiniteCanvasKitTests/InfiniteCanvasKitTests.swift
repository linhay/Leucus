import CoreGraphics
import Testing
@testable import InfiniteCanvasKit

struct InfiniteCanvasKitTests {
  @Test
  func panShouldAccumulateOffset() {
    var viewport = InfiniteCanvasViewport()

    viewport.pan(by: CGSize(width: 20, height: -12))
    viewport.pan(by: CGSize(width: -5, height: 4))

    #expect(viewport.offset == CGPoint(x: 15, y: -8))
  }

  @Test
  func zoomShouldKeepAnchorStable() {
    var viewport = InfiniteCanvasViewport(scale: 1, offset: CGPoint(x: 30, y: -10))
    let viewportSize = CGSize(width: 1200, height: 800)
    let anchor = CGPoint(x: 420, y: 260)
    let before = viewport.viewToWorld(anchor, viewportSize: viewportSize)

    viewport.zoom(multiplier: 1.6, anchorInView: anchor, viewportSize: viewportSize)
    let after = viewport.worldToView(before, viewportSize: viewportSize)

    #expect(abs(after.x - anchor.x) < 0.0001)
    #expect(abs(after.y - anchor.y) < 0.0001)
  }

  @Test
  func zoomShouldClampToBounds() {
    var viewport = InfiniteCanvasViewport(scale: 1, minScale: 0.5, maxScale: 2)

    viewport.zoom(multiplier: 100, anchorInView: .zero, viewportSize: CGSize(width: 1000, height: 800))
    #expect(viewport.scale == 2)

    viewport.zoom(multiplier: 0.001, anchorInView: .zero, viewportSize: CGSize(width: 1000, height: 800))
    #expect(viewport.scale == 0.5)
  }

  @Test
  func nodeShouldTranslateAndResizeWithClamp() {
    var node = CanvasNodeCard(
      title: "Node",
      position: CGPoint(x: 10, y: 20),
      size: CGSize(width: 220, height: 180)
    )
    node.translate(by: CGSize(width: 30, height: -10))
    node.resizeBy(delta: CGSize(width: -500, height: -500))

    #expect(node.position == CGPoint(x: 40, y: 10))
    #expect(node.size == CanvasNodeCard.minimumSize)
  }

  @Test
  func marqueeSelectionShouldReturnIntersectedNodes() {
    let a = CanvasNodeCard(title: "A", position: CGPoint(x: 0, y: 0), size: CGSize(width: 100, height: 80))
    let b = CanvasNodeCard(title: "B", position: CGPoint(x: 300, y: 200), size: CGSize(width: 100, height: 80))
    let c = CanvasNodeCard(title: "C", position: CGPoint(x: 60, y: 40), size: CGSize(width: 100, height: 80))

    let selected = selectedNodeIDs(
      in: CGRect(x: -10, y: -10, width: 220, height: 160),
      from: [a, b, c]
    )

    #expect(selected.contains(a.id))
    #expect(selected.contains(c.id))
    #expect(!selected.contains(b.id))
  }

  @Test
  func resizeFromLeftShouldMoveOriginAndClampWidth() {
    var node = CanvasNodeCard(
      title: "Node",
      position: CGPoint(x: 100, y: 40),
      size: CGSize(width: 220, height: 180)
    )

    node.resize(using: .left, delta: CGSize(width: 80, height: 0))
    #expect(node.position == CGPoint(x: 160, y: 40))
    #expect(node.size == CGSize(width: 160, height: 180))

    node.resize(using: .left, delta: CGSize(width: 200, height: 0))
    #expect(node.size.width == CanvasNodeCard.minimumSize.width)
  }

  @Test
  func resizeFromBottomRightShouldChangeWidthAndHeight() {
    var node = CanvasNodeCard(
      title: "Node",
      position: CGPoint(x: 0, y: 0),
      size: CGSize(width: 200, height: 160)
    )

    node.resize(using: .bottomRight, delta: CGSize(width: 40, height: -20))
    #expect(node.size == CGSize(width: 240, height: 180))
    #expect(node.position == CGPoint(x: 0, y: -20))
  }
}
