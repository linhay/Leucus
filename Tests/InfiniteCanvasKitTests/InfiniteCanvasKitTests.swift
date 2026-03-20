import CoreGraphics
import Foundation
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

  @Test
  func terminalFactoryShouldCreateTerminalKindNode() {
    let node = CanvasNodeCard.terminal(
      at: CGPoint(x: 12, y: 34),
      workingDirectory: "/Users/linhey/Workspace/demo",
      title: "demo"
    )
    #expect(node.kind == .terminal)
    #expect(node.group == .folder)
    #expect(node.groupLabel == "Workspace")
    #expect(node.title == "demo")
    #expect(node.workingDirectory == "/Users/linhey/Workspace/demo")
    #expect(node.position == CGPoint(x: 12, y: 34))
  }

  @Test
  func arrowNavigationShouldPickNearestNodeInDirection() {
    let center = CanvasNodeCard(title: "Center", position: CGPoint(x: 0, y: 0), size: CGSize(width: 100, height: 100))
    let left = CanvasNodeCard(title: "Left", position: CGPoint(x: -300, y: 0), size: CGSize(width: 100, height: 100))
    let right = CanvasNodeCard(title: "Right", position: CGPoint(x: 300, y: 0), size: CGSize(width: 100, height: 100))
    let up = CanvasNodeCard(title: "Up", position: CGPoint(x: 0, y: 300), size: CGSize(width: 100, height: 100))
    let down = CanvasNodeCard(title: "Down", position: CGPoint(x: 0, y: -300), size: CGSize(width: 100, height: 100))
    let nodes = [center, left, right, up, down]

    #expect(nextNodeID(from: center.id, direction: .left, in: nodes) == left.id)
    #expect(nextNodeID(from: center.id, direction: .right, in: nodes) == right.id)
    #expect(nextNodeID(from: center.id, direction: .up, in: nodes) == up.id)
    #expect(nextNodeID(from: center.id, direction: .down, in: nodes) == down.id)
  }

  @Test
  func finderPathShouldOnlyBeAvailableForTerminalNode() {
    let terminal = CanvasNodeCard.terminal(
      at: CGPoint(x: 0, y: 0),
      workingDirectory: "/Users/linhey/Workspace/demo"
    )
    let placeholder = CanvasNodeCard(
      kind: .placeholder,
      title: "placeholder",
      position: .zero
    )

    #expect(finderOpenPath(for: terminal) == "/Users/linhey/Workspace/demo")
    #expect(finderOpenPath(for: placeholder) == nil)
  }

  @Test
  func nodeShouldReportMinimumSizeState() {
    var node = CanvasNodeCard(
      title: "Node",
      position: .zero,
      size: CGSize(width: 300, height: 220)
    )
    #expect(!node.isAtMinimumSize)

    node.resizeBy(delta: CGSize(width: -500, height: -500))
    #expect(node.size == CanvasNodeCard.minimumSize)
    #expect(node.isAtMinimumSize)
  }

  @Test
  func snapshotStoreShouldRoundtripCanvasState() {
    let node = CanvasNodeCard.terminal(
      at: CGPoint(x: 20, y: 40),
      workingDirectory: "/Users/linhey/Workspace/demo",
      title: "demo"
    )
    let viewport = InfiniteCanvasViewport(
      scale: 1.3,
      offset: CGPoint(x: 12, y: -8),
      minScale: 0.4,
      maxScale: 2.4
    )
    let snapshot = CanvasStateSnapshot(
      nodes: [node],
      selectedNodeIDs: [node.id],
      viewport: viewport
    )

    let url = FileManager.default.temporaryDirectory
      .appendingPathComponent("canvas-snapshot-\(UUID().uuidString)")
      .appendingPathExtension("json")
    defer { try? FileManager.default.removeItem(at: url) }

    #expect(CanvasSnapshotStore.save(snapshot, to: url))
    guard let loaded = CanvasSnapshotStore.load(from: url) else {
      Issue.record("snapshot should load from saved file")
      return
    }
    #expect(loaded == snapshot)
    #expect(loaded.materializeNodes().first?.workingDirectory == "/Users/linhey/Workspace/demo")
  }

  @Test
  func resizeHitTestShouldPreferCornerBeforeEdge() {
    let rect = CGRect(x: 100, y: 100, width: 320, height: 220)
    let cornerPoint = CGPoint(x: rect.maxX, y: rect.maxY)
    let handle = CanvasNodeResizeGeometry.hitHandle(
      at: cornerPoint,
      in: rect,
      handleVisualSize: 10,
      edgeHitWidth: 12
    )
    #expect(handle == .topRight)
  }

  @Test
  func resizeHitTestShouldHitEdgeAwayFromCorner() {
    let rect = CGRect(x: 20, y: 20, width: 300, height: 200)
    let pointNearTopEdge = CGPoint(x: rect.midX, y: rect.maxY + 2)
    let handle = CanvasNodeResizeGeometry.hitHandle(
      at: pointNearTopEdge,
      in: rect,
      handleVisualSize: 10,
      edgeHitWidth: 12
    )
    #expect(handle == .top)
  }

  @Test
  func resizeHighlightRectsShouldMapToExpectedEdges() {
    let rect = CGRect(x: 10, y: 10, width: 200, height: 120)
    let topRects = CanvasNodeResizeGeometry.highlightRects(for: .top, in: rect, thickness: 3)
    #expect(topRects.count == 1)
    #expect(topRects[0].minY == rect.maxY - 3)
    #expect(topRects[0].height == 3)

    let cornerRects = CanvasNodeResizeGeometry.highlightRects(for: .bottomLeft, in: rect, thickness: 3)
    #expect(cornerRects.count == 2)
  }
}
