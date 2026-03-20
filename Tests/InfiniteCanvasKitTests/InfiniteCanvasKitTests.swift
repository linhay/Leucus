import CoreGraphics
import Foundation
import AppKit
import Testing
@testable import InfiniteCanvasKit

struct InfiniteCanvasKitTests {
  @Test
  func scrollPanMappingShouldKeepHorizontalAndInvertVertical() {
    let delta = CanvasScrollPanMapping.panDelta(scrollDeltaX: 14, scrollDeltaY: -9)
    #expect(delta == CGSize(width: 14, height: 9))
  }

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
  func folderFactoryShouldCreateFolderKindNode() {
    let node = CanvasNodeCard.folder(
      at: CGPoint(x: 22, y: 48),
      workingDirectory: "/Users/linhey/Workspace/demo",
      title: "demo"
    )
    #expect(node.kind == .folder)
    #expect(node.group == .folder)
    #expect(node.groupLabel == "Workspace")
    #expect(node.title == "demo")
    #expect(node.workingDirectory == "/Users/linhey/Workspace/demo")
    #expect(node.position == CGPoint(x: 22, y: 48))
  }

  @Test
  func convertingTerminalToFolderShouldKeepIdentityAndGeometry() {
    let terminal = CanvasNodeCard.terminal(
      at: CGPoint(x: 30, y: 44),
      workingDirectory: "/Users/linhey/Workspace/demo",
      title: "workspace",
      size: CGSize(width: 360, height: 240)
    )

    let folder = terminal.converted(to: .folder)

    #expect(folder.id == terminal.id)
    #expect(folder.kind == .folder)
    #expect(folder.group == .folder)
    #expect(folder.groupLabel == "Workspace")
    #expect(folder.title == terminal.title)
    #expect(folder.workingDirectory == terminal.workingDirectory)
    #expect(folder.position == terminal.position)
    #expect(folder.size == terminal.size)
  }

  @Test
  func convertingFolderToTerminalShouldKeepIdentityAndGeometry() {
    let folder = CanvasNodeCard.folder(
      at: CGPoint(x: 60, y: 88),
      workingDirectory: "/Users/linhey/Projects/canvas",
      title: "canvas",
      size: CGSize(width: 420, height: 260)
    )

    let terminal = folder.converted(to: .terminal)

    #expect(terminal.id == folder.id)
    #expect(terminal.kind == .terminal)
    #expect(terminal.group == .folder)
    #expect(terminal.groupLabel == "Projects")
    #expect(terminal.title == folder.title)
    #expect(terminal.workingDirectory == folder.workingDirectory)
    #expect(terminal.position == folder.position)
    #expect(terminal.size == folder.size)
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
  func finderPathShouldBeAvailableForTerminalAndFolderNode() {
    let terminal = CanvasNodeCard.terminal(
      at: CGPoint(x: 0, y: 0),
      workingDirectory: "/Users/linhey/Workspace/demo"
    )
    let folder = CanvasNodeCard.folder(
      at: CGPoint(x: 0, y: 0),
      workingDirectory: "/Users/linhey/Workspace/demo",
      title: "demo"
    )
    let placeholder = CanvasNodeCard(
      kind: .placeholder,
      title: "placeholder",
      position: .zero
    )

    #expect(finderOpenPath(for: terminal) == "/Users/linhey/Workspace/demo")
    #expect(finderOpenPath(for: folder) == "/Users/linhey/Workspace/demo")
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

  @Test
  func bringNodeToFrontShouldMoveTargetToEnd() {
    let a = CanvasNodeCard(title: "A", position: CGPoint(x: 0, y: 0))
    let b = CanvasNodeCard(title: "B", position: CGPoint(x: 10, y: 10))
    let c = CanvasNodeCard(title: "C", position: CGPoint(x: 20, y: 20))

    let reordered = bringNodeToFront(id: b.id, in: [a, b, c])
    #expect(reordered.map(\.id) == [a.id, c.id, b.id])
  }

  @Test
  func bringNodeToFrontShouldKeepOrderWhenIDMissing() {
    let a = CanvasNodeCard(title: "A", position: CGPoint(x: 0, y: 0))
    let b = CanvasNodeCard(title: "B", position: CGPoint(x: 10, y: 10))
    let missingID = UUID()

    let reordered = bringNodeToFront(id: missingID, in: [a, b])
    #expect(reordered.map(\.id) == [a.id, b.id])
  }

  @Test
  @MainActor
  func canvasSelectNodeShouldBringTargetToFront() {
    let a = CanvasNodeCard(title: "A", position: CGPoint(x: 0, y: 0))
    let b = CanvasNodeCard(title: "B", position: CGPoint(x: 100, y: 100))
    let view = InfiniteCanvasView(frame: CGRect(x: 0, y: 0, width: 800, height: 600))
    view.nodes = [a, b]

    view.selectNode(id: a.id)

    #expect(view.nodes.last?.id == a.id)
    #expect(view.selectedNodeIDs == [a.id])
  }

  @Test
  @MainActor
  func canvasAlignSelectionToGridShouldSnapOnlySelectedNode() {
    let a = CanvasNodeCard(title: "A", position: CGPoint(x: 13, y: 27), size: CGSize(width: 120, height: 80))
    let b = CanvasNodeCard(title: "B", position: CGPoint(x: 37, y: 49), size: CGSize(width: 120, height: 80))
    let view = InfiniteCanvasView(frame: CGRect(x: 0, y: 0, width: 800, height: 600))
    view.nodes = [a, b]
    view.selectedNodeIDs = [b.id]

    view.alignSelectionToGrid(step: 24)

    #expect(view.nodes[0].position == a.position)
    #expect(view.nodes[1].position == CGPoint(x: 48, y: 48))
  }

  @Test
  @MainActor
  func nodeContextMenuShouldContainDetachActionAndEmitNodeID() {
    let node = CanvasNodeCard.terminal(at: .zero, title: "Terminal")
    let view = InfiniteCanvasView(frame: CGRect(x: 0, y: 0, width: 800, height: 600))
    view.nodes = [node]

    var requestedID: UUID?
    view.onDetachNodeRequested = { requestedID = $0 }

    let window = NSWindow(
      contentRect: CGRect(x: 100, y: 100, width: 800, height: 600),
      styleMask: [.titled, .closable],
      backing: .buffered,
      defer: false
    )
    window.contentView = view
    defer {
      window.orderOut(nil)
      window.close()
    }

    let pointInView = CGPoint(x: 410, y: 310)
    let pointInWindow = view.convert(pointInView, to: nil)
    guard
      let event = NSEvent.mouseEvent(
        with: .rightMouseDown,
        location: pointInWindow,
        modifierFlags: [],
        timestamp: 0,
        windowNumber: window.windowNumber,
        context: nil,
        eventNumber: 0,
        clickCount: 1,
        pressure: 1
      )
    else {
      Issue.record("failed to create right click event")
      return
    }

    guard let menu = view.menu(for: event) else {
      Issue.record("node context menu should be available")
      return
    }

    guard let index = menu.items.firstIndex(where: { $0.title == "展开为独立窗口" }) else {
      Issue.record("detach action should be present in node context menu")
      return
    }

    menu.performActionForItem(at: index)
    #expect(requestedID == node.id)
  }

  @Test
  func folderBrowserEntriesShouldSortDirectoryBeforeFile() throws {
    let baseURL = FileManager.default.temporaryDirectory
      .appendingPathComponent("canvas-folder-browser-\(UUID().uuidString)", isDirectory: true)
    try FileManager.default.createDirectory(at: baseURL, withIntermediateDirectories: true)
    defer { try? FileManager.default.removeItem(at: baseURL) }

    let subdir = baseURL.appendingPathComponent("sub", isDirectory: true)
    try FileManager.default.createDirectory(at: subdir, withIntermediateDirectories: true)
    let file = baseURL.appendingPathComponent("z.txt", isDirectory: false)
    FileManager.default.createFile(atPath: file.path, contents: Data("ok".utf8))

    let entries = FolderBrowserModel.entries(at: baseURL.path)
    #expect(entries.count >= 2)

    let names = entries.map(\.name)
    #expect(names.first == "sub")
    #expect(names.contains("z.txt"))
    #expect(entries.first?.kind == .folder)
  }

  @Test
  func folderBrowserParentPathShouldReturnNilAtRoot() {
    #expect(FolderBrowserModel.parentPath(of: "/") == nil)
  }

  @Test
  func folderBrowserResolvedPathShouldFallbackForInvalidInput() {
    let resolved = FolderBrowserModel.resolvedDirectoryPath(
      preferred: "/path/that/does/not/exist/\(UUID().uuidString)"
    )
    #expect(!resolved.isEmpty)
    #expect(FileManager.default.fileExists(atPath: resolved))
  }

  @Test
  func organizeNodeCardsShouldCreateBalancedNonOverlappingGrid() {
    let nodes: [CanvasNodeCard] = [
      CanvasNodeCard(title: "A", position: CGPoint(x: 140, y: 30), size: CGSize(width: 200, height: 120)),
      CanvasNodeCard(title: "B", position: CGPoint(x: 50, y: 260), size: CGSize(width: 180, height: 140)),
      CanvasNodeCard(title: "C", position: CGPoint(x: 300, y: -40), size: CGSize(width: 160, height: 110)),
      CanvasNodeCard(title: "D", position: CGPoint(x: -20, y: 80), size: CGSize(width: 220, height: 130)),
      CanvasNodeCard(title: "E", position: CGPoint(x: 80, y: -160), size: CGSize(width: 190, height: 100)),
    ]

    let organized = organizeNodeCards(nodes, spacing: 20)

    #expect(organized.map(\.id) == nodes.map(\.id))
    #expect(organized[0].position == CGPoint(x: -20, y: 280))
    #expect(organized[1].position == CGPoint(x: 200, y: 260))
    #expect(organized[2].position == CGPoint(x: 400, y: 290))
    #expect(organized[3].position == CGPoint(x: -20, y: 110))
    #expect(organized[4].position == CGPoint(x: 220, y: 140))

    for i in organized.indices {
      for j in organized.indices where j > i {
        #expect(!organized[i].worldRect.intersects(organized[j].worldRect))
      }
    }
  }

  @Test
  func alignNodeCardsToGridShouldOnlyAffectTargetNodes() {
    let a = CanvasNodeCard(title: "A", position: CGPoint(x: 13, y: 27), size: CGSize(width: 100, height: 80))
    let b = CanvasNodeCard(title: "B", position: CGPoint(x: 37, y: 49), size: CGSize(width: 120, height: 90))
    let c = CanvasNodeCard(title: "C", position: CGPoint(x: 75, y: 11), size: CGSize(width: 110, height: 70))
    let nodes = [a, b, c]

    let aligned = alignNodeCardsToGrid(nodes, targetIDs: [b.id], step: 24)

    #expect(aligned[0].position == a.position)
    #expect(aligned[1].position == CGPoint(x: 48, y: 48))
    #expect(aligned[2].position == c.position)
  }
}
