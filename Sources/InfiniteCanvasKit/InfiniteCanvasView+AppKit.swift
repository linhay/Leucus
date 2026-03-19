#if canImport(AppKit) && !canImport(UIKit)
import AppKit

@MainActor
public final class InfiniteCanvasView: NSView {
  public var viewport = InfiniteCanvasViewport() {
    didSet { needsDisplay = true }
  }

  public var nodes: [CanvasNodeCard] = [] {
    didSet { needsDisplay = true }
  }

  public var selectedNodeIDs: Set<UUID> = [] {
    didSet { needsDisplay = true }
  }

  public var backgroundColor = NSColor(calibratedWhite: 0.09, alpha: 1) {
    didSet { needsDisplay = true }
  }

  public var dotColor = NSColor(calibratedWhite: 1, alpha: 0.16) {
    didSet { needsDisplay = true }
  }

  private enum Interaction {
    case idle
    case panning(lastPointInView: CGPoint)
    case marquee(startInView: CGPoint, currentInView: CGPoint)
    case moving(startInWorld: CGPoint, initialPositions: [UUID: CGPoint])
    case resizing(id: UUID, handle: CanvasNodeResizeHandle, startInWorld: CGPoint, initialNode: CanvasNodeCard)
  }

  private var interaction: Interaction = .idle

  private let headerHeight: CGFloat = 32
  private let closeButtonSize: CGFloat = 16
  private let resizeHandleSize: CGFloat = 10

  public override var acceptsFirstResponder: Bool { true }

  public override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    wantsLayer = true
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    nil
  }

  public override func mouseDown(with event: NSEvent) {
    window?.makeFirstResponder(self)
    let point = convert(event.locationInWindow, from: nil)

    if event.modifierFlags.contains(.option) {
      interaction = .panning(lastPointInView: point)
      return
    }

    guard let hit = hitTestNode(at: point) else {
      selectedNodeIDs.removeAll()
      interaction = .marquee(startInView: point, currentInView: point)
      return
    }

    if let closeRect = closeButtonRect(for: hit.rectInView), closeRect.contains(point) {
      removeNode(id: hit.node.id)
      interaction = .idle
      return
    }

    if let resize = resizeHandle(at: point, in: hit.rectInView) {
      interaction = .resizing(
        id: hit.node.id,
        handle: resize,
        startInWorld: viewport.viewToWorld(point, viewportSize: bounds.size),
        initialNode: hit.node
      )
      selectedNodeIDs = [hit.node.id]
      return
    }

    if headerRect(for: hit.rectInView).contains(point) {
      if !selectedNodeIDs.contains(hit.node.id) {
        selectedNodeIDs = [hit.node.id]
      }
      let startWorld = viewport.viewToWorld(point, viewportSize: bounds.size)
      let initial = Dictionary(uniqueKeysWithValues: nodes
        .filter { selectedNodeIDs.contains($0.id) }
        .map { ($0.id, $0.position) })
      interaction = .moving(startInWorld: startWorld, initialPositions: initial)
      return
    }

    selectedNodeIDs = [hit.node.id]
    interaction = .idle
  }

  public override func mouseDragged(with event: NSEvent) {
    let point = convert(event.locationInWindow, from: nil)

    switch interaction {
    case let .panning(lastPoint):
      let delta = CGSize(width: point.x - lastPoint.x, height: point.y - lastPoint.y)
      viewport.pan(by: delta)
      interaction = .panning(lastPointInView: point)

    case let .marquee(start, _):
      interaction = .marquee(startInView: start, currentInView: point)
      needsDisplay = true

    case let .moving(startWorld, initialPositions):
      let currentWorld = viewport.viewToWorld(point, viewportSize: bounds.size)
      let deltaWorld = CGSize(
        width: currentWorld.x - startWorld.x,
        height: currentWorld.y - startWorld.y
      )
      for index in nodes.indices {
        let id = nodes[index].id
        guard let initial = initialPositions[id] else { continue }
        nodes[index].position = CGPoint(
          x: initial.x + deltaWorld.width,
          y: initial.y + deltaWorld.height
        )
      }

    case let .resizing(id, handle, startWorld, initialNode):
      let currentWorld = viewport.viewToWorld(point, viewportSize: bounds.size)
      let deltaWorld = CGSize(
        width: currentWorld.x - startWorld.x,
        height: currentWorld.y - startWorld.y
      )
      guard let index = nodes.firstIndex(where: { $0.id == id }) else { return }
      var node = initialNode
      node.resize(using: handle, delta: deltaWorld)
      nodes[index] = node

    case .idle:
      break
    }
  }

  public override func mouseUp(with _: NSEvent) {
    if case let .marquee(start, current) = interaction {
      let worldRect = worldSelectionRect(fromViewStart: start, end: current)
      selectedNodeIDs = InfiniteCanvasKit.selectedNodeIDs(in: worldRect, from: nodes)
    }
    interaction = .idle
    needsDisplay = true
  }

  public override func scrollWheel(with event: NSEvent) {
    if event.modifierFlags.contains(.command) {
      let anchor = convert(event.locationInWindow, from: nil)
      let factor = 1 + event.scrollingDeltaY * 0.01
      viewport.zoom(multiplier: factor, anchorInView: anchor, viewportSize: bounds.size)
      return
    }
    let delta = CGSize(width: -event.scrollingDeltaX, height: event.scrollingDeltaY)
    viewport.pan(by: delta)
  }

  public override func magnify(with event: NSEvent) {
    let anchor = convert(event.locationInWindow, from: nil)
    viewport.zoom(
      multiplier: 1 + event.magnification,
      anchorInView: anchor,
      viewportSize: bounds.size
    )
  }

  public override func draw(_ dirtyRect: NSRect) {
    backgroundColor.setFill()
    dirtyRect.fill()

    drawDotGrid(in: dirtyRect)
    drawCards()
    drawMarqueeIfNeeded()
  }

  private func drawDotGrid(in dirtyRect: NSRect) {
    let spacing = max(12, 24 * viewport.scale)
    guard spacing.isFinite, spacing > 0 else { return }

    let radius: CGFloat = max(0.8, 1.5 * viewport.scale)
    let phaseX = normalizedPhase(viewport.offset.x + bounds.midX, spacing: spacing)
    let phaseY = normalizedPhase(viewport.offset.y + bounds.midY, spacing: spacing)

    let dotsPath = NSBezierPath()
    var x = phaseX
    while x < dirtyRect.maxX + spacing {
      var y = phaseY
      while y < dirtyRect.maxY + spacing {
        dotsPath.appendOval(in: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
        y += spacing
      }
      x += spacing
    }

    dotColor.setFill()
    dotsPath.fill()
  }

  private func drawCards() {
    for node in nodes {
      let rect = viewRect(for: node)
      let selected = selectedNodeIDs.contains(node.id)
      drawCardBackground(rect: rect, selected: selected)
      drawCardHeader(node: node, rect: rect)
      drawCardBodyHint(rect: rect)
      if selected {
        drawResizeHandles(in: rect)
      }
    }
  }

  private func drawCardBackground(rect: CGRect, selected: Bool) {
    let rounded = NSBezierPath(roundedRect: rect, xRadius: 14, yRadius: 14)
    NSColor(calibratedWhite: 1, alpha: selected ? 0.1 : 0.07).setFill()
    rounded.fill()

    NSColor(calibratedWhite: 1, alpha: selected ? 0.5 : 0.22).setStroke()
    rounded.lineWidth = selected ? 1.5 : 1
    rounded.stroke()
  }

  private func drawCardHeader(node: CanvasNodeCard, rect: CGRect) {
    let hRect = headerRect(for: rect)
    let path = NSBezierPath(roundedRect: hRect, xRadius: 14, yRadius: 14)
    NSColor(calibratedWhite: 1, alpha: 0.08).setFill()
    path.fill()

    let titleAttributes: [NSAttributedString.Key: Any] = [
      .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
      .foregroundColor: NSColor(calibratedWhite: 1, alpha: 0.9),
    ]
    (node.title as NSString).draw(
      at: CGPoint(x: hRect.minX + 12, y: hRect.midY - 7),
      withAttributes: titleAttributes
    )

    if let closeRect = closeButtonRect(for: rect) {
      let closePath = NSBezierPath(ovalIn: closeRect)
      NSColor(calibratedRed: 1, green: 0.35, blue: 0.35, alpha: 0.85).setFill()
      closePath.fill()

      let cross = NSBezierPath()
      cross.lineWidth = 1.4
      NSColor.white.withAlphaComponent(0.9).setStroke()
      cross.move(to: CGPoint(x: closeRect.minX + 4.5, y: closeRect.minY + 4.5))
      cross.line(to: CGPoint(x: closeRect.maxX - 4.5, y: closeRect.maxY - 4.5))
      cross.move(to: CGPoint(x: closeRect.maxX - 4.5, y: closeRect.minY + 4.5))
      cross.line(to: CGPoint(x: closeRect.minX + 4.5, y: closeRect.maxY - 4.5))
      cross.stroke()
    }
  }

  private func drawCardBodyHint(rect: CGRect) {
    let subtitleAttributes: [NSAttributedString.Key: Any] = [
      .font: NSFont.systemFont(ofSize: 12, weight: .regular),
      .foregroundColor: NSColor(calibratedWhite: 1, alpha: 0.52),
    ]
    ("空节点（类型待定）" as NSString).draw(
      at: CGPoint(x: rect.minX + 12, y: rect.minY + 12),
      withAttributes: subtitleAttributes
    )
  }

  private func drawResizeHandles(in rect: CGRect) {
    for (_, handleRect) in resizeHandleRects(for: rect) {
      let path = NSBezierPath(roundedRect: handleRect, xRadius: 2, yRadius: 2)
      NSColor(calibratedWhite: 1, alpha: 0.9).setFill()
      path.fill()
    }
  }

  private func drawMarqueeIfNeeded() {
    guard case let .marquee(start, current) = interaction else { return }
    let rect = CGRect(
      x: min(start.x, current.x),
      y: min(start.y, current.y),
      width: abs(current.x - start.x),
      height: abs(current.y - start.y)
    )
    let path = NSBezierPath(rect: rect)
    NSColor(calibratedRed: 0.4, green: 0.7, blue: 1, alpha: 0.15).setFill()
    path.fill()
    NSColor(calibratedRed: 0.4, green: 0.7, blue: 1, alpha: 0.8).setStroke()
    path.lineWidth = 1
    path.stroke()
  }

  private func removeNode(id: UUID) {
    nodes.removeAll { $0.id == id }
    selectedNodeIDs.remove(id)
  }

  private func hitTestNode(at point: CGPoint) -> (node: CanvasNodeCard, rectInView: CGRect)? {
    for node in nodes.reversed() {
      let rect = viewRect(for: node)
      if rect.contains(point) {
        return (node, rect)
      }
    }
    return nil
  }

  private func resizeHandle(at point: CGPoint, in rect: CGRect) -> CanvasNodeResizeHandle? {
    for (handle, handleRect) in resizeHandleRects(for: rect) {
      if handleRect.contains(point) {
        return handle
      }
    }
    return nil
  }

  private func resizeHandleRects(for rect: CGRect) -> [(CanvasNodeResizeHandle, CGRect)] {
    let s = resizeHandleSize
    let hs = s * 0.5
    return [
      (.topLeft, CGRect(x: rect.minX - hs, y: rect.maxY - hs, width: s, height: s)),
      (.top, CGRect(x: rect.midX - hs, y: rect.maxY - hs, width: s, height: s)),
      (.topRight, CGRect(x: rect.maxX - hs, y: rect.maxY - hs, width: s, height: s)),
      (.right, CGRect(x: rect.maxX - hs, y: rect.midY - hs, width: s, height: s)),
      (.bottomRight, CGRect(x: rect.maxX - hs, y: rect.minY - hs, width: s, height: s)),
      (.bottom, CGRect(x: rect.midX - hs, y: rect.minY - hs, width: s, height: s)),
      (.bottomLeft, CGRect(x: rect.minX - hs, y: rect.minY - hs, width: s, height: s)),
      (.left, CGRect(x: rect.minX - hs, y: rect.midY - hs, width: s, height: s)),
    ]
  }

  private func headerRect(for rect: CGRect) -> CGRect {
    CGRect(x: rect.minX, y: rect.maxY - headerHeight, width: rect.width, height: headerHeight)
  }

  private func closeButtonRect(for rect: CGRect) -> CGRect? {
    let header = headerRect(for: rect)
    guard header.width > 44 else { return nil }
    return CGRect(
      x: header.maxX - closeButtonSize - 10,
      y: header.midY - closeButtonSize * 0.5,
      width: closeButtonSize,
      height: closeButtonSize
    )
  }

  private func worldSelectionRect(fromViewStart start: CGPoint, end: CGPoint) -> CGRect {
    let a = viewport.viewToWorld(start, viewportSize: bounds.size)
    let b = viewport.viewToWorld(end, viewportSize: bounds.size)
    return CGRect(
      x: min(a.x, b.x),
      y: min(a.y, b.y),
      width: abs(a.x - b.x),
      height: abs(a.y - b.y)
    )
  }

  private func viewRect(for node: CanvasNodeCard) -> CGRect {
    let origin = viewport.worldToView(node.position, viewportSize: bounds.size)
    return CGRect(
      x: origin.x,
      y: origin.y,
      width: node.size.width * viewport.scale,
      height: node.size.height * viewport.scale
    )
  }

  private func normalizedPhase(_ value: CGFloat, spacing: CGFloat) -> CGFloat {
    let mod = value.truncatingRemainder(dividingBy: spacing)
    return mod >= 0 ? mod : mod + spacing
  }
}
#endif
