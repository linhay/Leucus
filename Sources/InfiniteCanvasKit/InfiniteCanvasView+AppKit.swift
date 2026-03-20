#if canImport(AppKit) && !canImport(UIKit)
import AppKit

@MainActor
public final class InfiniteCanvasView: NSView {
  public var viewport = InfiniteCanvasViewport() {
    didSet {
      needsDisplay = true
      scheduleAutosave()
      notifyNodeLayoutsChanged()
    }
  }

  public var nodes: [CanvasNodeCard] = [] {
    didSet {
      needsDisplay = true
      scheduleAutosave()
      notifyNodeLayoutsChanged()
    }
  }

  public var selectedNodeIDs: Set<UUID> = [] {
    didSet {
      needsDisplay = true
      scheduleAutosave()
      notifyNodeLayoutsChanged()
    }
  }

  public var onNodeLayoutsChanged: (([CanvasNodeLayout]) -> Void)? {
    didSet { notifyNodeLayoutsChanged() }
  }

  public var onResizeInteractionChanged: ((Bool) -> Void)?

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
  private var contextMenuPointInView: CGPoint?
  private var contextMenuNodeID: UUID?
  private var autosaveKey: String?
  private var autosaveWorkItem: DispatchWorkItem?
  private var isRestoringState = false
  private var trackingArea: NSTrackingArea?
  private var hoveredResizeTarget: HoveredResizeTarget?

  private let headerHeight: CGFloat = 32
  private let closeButtonSize: CGFloat = 16
  private let resizeHandleSize: CGFloat = 10
  private let resizeEdgeHitWidth: CGFloat = 12
  private let resizeHoverStrokeWidth: CGFloat = 2.5

  private struct HoveredResizeTarget: Equatable {
    let id: UUID
    let handle: CanvasNodeResizeHandle
  }

  public override var acceptsFirstResponder: Bool { true }

  public func selectNode(id: UUID) {
    selectSingleNode(id)
  }

  public override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    wantsLayer = true
    registerForDraggedTypes([.fileURL])
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    nil
  }

  @discardableResult
  public func configurePersistence(key: String, restoreOnConfigure: Bool = true) -> Bool {
    autosaveKey = key
    guard restoreOnConfigure, let snapshot = CanvasSnapshotStore.load(key: key) else {
      return false
    }
    restore(from: snapshot)
    return true
  }

  public func restore(from snapshot: CanvasStateSnapshot) {
    isRestoringState = true
    viewport = snapshot.materializeViewport()
    nodes = snapshot.materializeNodes()
    selectedNodeIDs = Set(snapshot.selectedNodeIDs)
    isRestoringState = false
  }

  public func persistNow() {
    autosaveWorkItem?.cancel()
    autosaveWorkItem = nil
    guard !isRestoringState, let key = autosaveKey else { return }
    _ = CanvasSnapshotStore.save(makeSnapshot(), key: key)
  }

  public override func mouseDown(with event: NSEvent) {
    window?.makeFirstResponder(self)
    let point = convert(event.locationInWindow, from: nil)

    if event.modifierFlags.contains(.option) {
      hoveredResizeTarget = nil
      interaction = .panning(lastPointInView: point)
      return
    }

    guard let hit = hitTestNode(at: point) else {
      selectedNodeIDs.removeAll()
      hoveredResizeTarget = nil
      interaction = .marquee(startInView: point, currentInView: point)
      return
    }

    let compact = isCompact(node: hit.node)

    if !compact, let closeRect = closeButtonRect(for: hit.rectInView), closeRect.contains(point) {
      removeNode(id: hit.node.id)
      interaction = .idle
      return
    }

    if let resize = resizeHandle(at: point, in: hit.rectInView) {
      hoveredResizeTarget = HoveredResizeTarget(id: hit.node.id, handle: resize)
      onResizeInteractionChanged?(true)
      interaction = .resizing(
        id: hit.node.id,
        handle: resize,
        startInWorld: viewport.viewToWorld(point, viewportSize: bounds.size),
        initialNode: hit.node
      )
      selectSingleNode(hit.node.id)
      return
    }

    if compact || headerRect(for: hit.rectInView).contains(point) {
      selectSingleNode(hit.node.id)
      let startWorld = viewport.viewToWorld(point, viewportSize: bounds.size)
      let initial = Dictionary(uniqueKeysWithValues: nodes
        .filter { selectedNodeIDs.contains($0.id) }
        .map { ($0.id, $0.position) })
      interaction = .moving(startInWorld: startWorld, initialPositions: initial)
      return
    }

    selectSingleNode(hit.node.id)
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

    if case .idle = interaction {
      updateHoveredResizeTarget(at: point)
    } else {
      hoveredResizeTarget = nil
    }
  }

  public override func mouseUp(with _: NSEvent) {
    let wasResizing = isResizingInteraction
    if case let .marquee(start, current) = interaction {
      let worldRect = worldSelectionRect(fromViewStart: start, end: current)
      selectedNodeIDs = InfiniteCanvasKit.selectedNodeIDs(in: worldRect, from: nodes)
    }
    interaction = .idle
    if wasResizing {
      onResizeInteractionChanged?(false)
    }
    if let event = NSApp.currentEvent {
      let point = convert(event.locationInWindow, from: nil)
      updateHoveredResizeTarget(at: point)
    }
    needsDisplay = true
  }

  public override func mouseMoved(with event: NSEvent) {
    guard case .idle = interaction else { return }
    let point = convert(event.locationInWindow, from: nil)
    updateHoveredResizeTarget(at: point)
  }

  public override func mouseExited(with _: NSEvent) {
    guard hoveredResizeTarget != nil else { return }
    hoveredResizeTarget = nil
    needsDisplay = true
  }

  public override func updateTrackingAreas() {
    super.updateTrackingAreas()
    if let trackingArea {
      removeTrackingArea(trackingArea)
    }
    let area = NSTrackingArea(
      rect: .zero,
      options: [.activeInKeyWindow, .inVisibleRect, .mouseMoved, .mouseEnteredAndExited],
      owner: self,
      userInfo: nil
    )
    addTrackingArea(area)
    trackingArea = area
  }

  public override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    window?.acceptsMouseMovedEvents = true
  }

  public override func keyDown(with event: NSEvent) {
    guard let direction = navigationDirection(from: event) else {
      super.keyDown(with: event)
      return
    }
    navigateSelection(to: direction)
  }

  public override func menu(for event: NSEvent) -> NSMenu? {
    let point = convert(event.locationInWindow, from: nil)
    contextMenuPointInView = point

    if let hit = hitTestNode(at: point) {
      contextMenuNodeID = hit.node.id
      selectSingleNode(hit.node.id)

      let menu = NSMenu(title: "Node")
      let closeItem = NSMenuItem(
        title: "关闭当前卡片",
        action: #selector(closeContextCard(_:)),
        keyEquivalent: ""
      )
      closeItem.target = self
      menu.addItem(closeItem)

      let openFinder = NSMenuItem(
        title: "在 Finder 中打开",
        action: #selector(openContextCardInFinder(_:)),
        keyEquivalent: ""
      )
      openFinder.target = self
      openFinder.isEnabled = finderPath(forNodeID: hit.node.id) != nil
      menu.addItem(openFinder)

      switch hit.node.kind {
      case .terminal:
        let switchToFolder = NSMenuItem(
          title: "切换为文件夹卡片",
          action: #selector(switchContextCardToFolder(_:)),
          keyEquivalent: ""
        )
        switchToFolder.target = self
        menu.addItem(switchToFolder)
      case .folder:
        let switchToTerminal = NSMenuItem(
          title: "切换为终端卡片",
          action: #selector(switchContextCardToTerminal(_:)),
          keyEquivalent: ""
        )
        switchToTerminal.target = self
        menu.addItem(switchToTerminal)
      case .placeholder:
        let switchToTerminal = NSMenuItem(
          title: "切换为终端卡片",
          action: #selector(switchContextCardToTerminal(_:)),
          keyEquivalent: ""
        )
        switchToTerminal.target = self
        menu.addItem(switchToTerminal)
      }
      return menu
    }

    contextMenuNodeID = nil
    let menu = NSMenu(title: "Canvas")
    let addFolder = NSMenuItem(
      title: "添加文件夹卡片",
      action: #selector(addFolderCardFromContextMenu(_:)),
      keyEquivalent: ""
    )
    addFolder.target = self
    addFolder.representedObject = NSValue(point: point)
    menu.addItem(addFolder)

    let addTerminal = NSMenuItem(
      title: "添加终端卡片",
      action: #selector(addTerminalCardFromContextMenu(_:)),
      keyEquivalent: ""
    )
    addTerminal.target = self
    addTerminal.representedObject = NSValue(point: point)
    menu.addItem(addTerminal)
    return menu
  }

  public override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
    droppedDirectoryURLs(from: sender.draggingPasteboard).isEmpty ? [] : .copy
  }

  public override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool {
    !droppedDirectoryURLs(from: sender.draggingPasteboard).isEmpty
  }

  public override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
    let directories = droppedDirectoryURLs(from: sender.draggingPasteboard)
    guard !directories.isEmpty else { return false }

    let anchorInView = convert(sender.draggingLocation, from: nil)
    let anchorWorld = viewport.viewToWorld(anchorInView, viewportSize: bounds.size)

    var lastID: UUID?
    for (index, url) in directories.enumerated() {
      let offset = CGFloat(index) * 24
      let node = CanvasNodeCard.folder(
        at: CGPoint(x: anchorWorld.x + offset, y: anchorWorld.y - offset),
        workingDirectory: url.path
      )
      nodes.append(node)
      lastID = node.id
    }
    if let lastID {
      selectSingleNode(lastID)
    }
    return true
  }

  public override func scrollWheel(with event: NSEvent) {
    if event.modifierFlags.contains(.command) {
      let anchor = convert(event.locationInWindow, from: nil)
      let factor = 1 + event.scrollingDeltaY * 0.01
      viewport.zoom(multiplier: factor, anchorInView: anchor, viewportSize: bounds.size)
      return
    }
    let delta = CanvasScrollPanMapping.panDelta(
      scrollDeltaX: event.scrollingDeltaX,
      scrollDeltaY: event.scrollingDeltaY
    )
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
    notifyNodeLayoutsChanged()
  }

  public override func layout() {
    super.layout()
    notifyNodeLayoutsChanged()
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
      if isCompact(node: node) {
        drawCompactCard(node: node, rect: rect)
      } else {
        drawCardHeader(node: node, rect: rect)
        drawCardBodyHint(node: node, rect: rect)
      }
      if let hoveredResizeTarget, hoveredResizeTarget.id == node.id {
        drawHoveredResizeBorder(in: rect, handle: hoveredResizeTarget.handle)
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

  private func drawCardBodyHint(node: CanvasNodeCard, rect: CGRect) {
    let subtitleAttributes: [NSAttributedString.Key: Any] = [
      .font: NSFont.systemFont(ofSize: 12, weight: .regular),
      .foregroundColor: NSColor(calibratedWhite: 1, alpha: 0.52),
    ]
    (subtitle(for: node) as NSString).draw(
      at: CGPoint(x: rect.minX + 12, y: rect.minY + 12),
      withAttributes: subtitleAttributes
    )
  }

  private func drawCompactCard(node: CanvasNodeCard, rect: CGRect) {
    let iconAttributes: [NSAttributedString.Key: Any] = [
      .font: NSFont.systemFont(ofSize: 15, weight: .semibold),
      .foregroundColor: NSColor(calibratedWhite: 1, alpha: 0.92),
    ]
    let titleAttributes: [NSAttributedString.Key: Any] = [
      .font: NSFont.systemFont(ofSize: 13, weight: .semibold),
      .foregroundColor: NSColor(calibratedWhite: 1, alpha: 0.9),
    ]
    let summaryParagraph = NSMutableParagraphStyle()
    summaryParagraph.lineBreakMode = .byTruncatingMiddle
    let summaryAttributes: [NSAttributedString.Key: Any] = [
      .font: NSFont.systemFont(ofSize: 12, weight: .regular),
      .foregroundColor: NSColor(calibratedWhite: 1, alpha: 0.58),
      .paragraphStyle: summaryParagraph,
    ]

    (iconText(for: node.kind) as NSString).draw(
      at: CGPoint(x: rect.minX + 12, y: rect.maxY - 30),
      withAttributes: iconAttributes
    )

    (node.title as NSString).draw(
      at: CGPoint(x: rect.minX + 34, y: rect.maxY - 30),
      withAttributes: titleAttributes
    )

    let summaryRect = CGRect(
      x: rect.minX + 12,
      y: rect.minY + 12,
      width: rect.width - 24,
      height: 18
    )
    (subtitle(for: node) as NSString).draw(in: summaryRect, withAttributes: summaryAttributes)
  }

  @objc
  private func addFolderCardFromContextMenu(_ sender: NSMenuItem) {
    let pointInView = (sender.representedObject as? NSValue)?.pointValue ?? contextMenuPointInView ?? .zero
    appendFolderCard(
      at: viewport.viewToWorld(pointInView, viewportSize: bounds.size),
      workingDirectory: nil,
      title: "Folder"
    )
  }

  @objc
  private func addTerminalCardFromContextMenu(_ sender: NSMenuItem) {
    let pointInView = (sender.representedObject as? NSValue)?.pointValue ?? contextMenuPointInView ?? .zero
    appendTerminalCard(
      at: viewport.viewToWorld(pointInView, viewportSize: bounds.size),
      workingDirectory: nil,
      title: "Terminal"
    )
  }

  @objc
  private func closeContextCard(_: NSMenuItem) {
    guard let id = contextMenuNodeID else { return }
    removeNode(id: id)
    contextMenuNodeID = nil
  }

  @objc
  private func openContextCardInFinder(_: NSMenuItem) {
    guard
      let id = contextMenuNodeID,
      let path = finderPath(forNodeID: id)
    else {
      return
    }
    NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: path)])
  }

  @objc
  private func switchContextCardToTerminal(_: NSMenuItem) {
    guard let id = contextMenuNodeID else { return }
    switchContextCard(id: id, to: .terminal)
  }

  @objc
  private func switchContextCardToFolder(_: NSMenuItem) {
    guard let id = contextMenuNodeID else { return }
    switchContextCard(id: id, to: .folder)
  }

  private func drawHoveredResizeBorder(in rect: CGRect, handle: CanvasNodeResizeHandle) {
    let highlightRects = CanvasNodeResizeGeometry.highlightRects(
      for: handle,
      in: rect,
      thickness: resizeHoverStrokeWidth
    )
    NSColor(calibratedRed: 0.39, green: 0.76, blue: 1.0, alpha: 0.95).setFill()
    for highlight in highlightRects {
      NSBezierPath(rect: highlight).fill()
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
    CanvasNodeResizeGeometry.hitHandle(
      at: point,
      in: rect,
      handleVisualSize: resizeHandleSize,
      edgeHitWidth: resizeEdgeHitWidth
    )
  }

  private func updateHoveredResizeTarget(at point: CGPoint) {
    guard let hit = hitTestNode(at: point), !isCompact(node: hit.node) else {
      if hoveredResizeTarget != nil {
        hoveredResizeTarget = nil
        needsDisplay = true
      }
      return
    }
    guard let handle = resizeHandle(at: point, in: hit.rectInView) else {
      if hoveredResizeTarget != nil {
        hoveredResizeTarget = nil
        needsDisplay = true
      }
      return
    }

    let next = HoveredResizeTarget(id: hit.node.id, handle: handle)
    guard hoveredResizeTarget != next else { return }
    hoveredResizeTarget = next
    needsDisplay = true
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

  private func contentRect(for node: CanvasNodeCard, frame: CGRect) -> CGRect {
    guard !isCompact(node: node) else { return .zero }
    let inset: CGFloat = 6
    let topInset = headerHeight + inset
    return CGRect(
      x: frame.minX + inset,
      y: frame.minY + inset,
      width: max(0, frame.width - inset * 2),
      height: max(0, frame.height - topInset - inset)
    )
  }

  private func currentNodeLayouts() -> [CanvasNodeLayout] {
    nodes.map { node in
      let frame = viewRect(for: node)
      let compact = isCompact(node: node)
      return CanvasNodeLayout(
        id: node.id,
        kind: node.kind,
        title: node.title,
        workingDirectory: node.workingDirectory,
        frame: frame,
        contentFrame: contentRect(for: node, frame: frame),
        isCompact: compact
      )
    }
  }

  private func notifyNodeLayoutsChanged() {
    onNodeLayoutsChanged?(currentNodeLayouts())
  }

  private func subtitle(for node: CanvasNodeCard) -> String {
    switch node.kind {
    case .terminal:
      let groupText = "文件夹大类: \(node.groupLabel ?? "未指定")"
      if let workingDirectory = node.workingDirectory, !workingDirectory.isEmpty {
        return "\(groupText) · \(workingDirectory)"
      }
      return groupText
    case .folder:
      let groupText = "文件夹大类: \(node.groupLabel ?? "未指定")"
      if let workingDirectory = node.workingDirectory, !workingDirectory.isEmpty {
        return "\(groupText) · \(workingDirectory)"
      }
      return groupText
    case .placeholder:
      return "空节点（类型待定）"
    }
  }

  private func iconText(for kind: CanvasNodeKind) -> String {
    switch kind {
    case .terminal:
      return "⌨"
    case .folder:
      return "📁"
    case .placeholder:
      return "□"
    }
  }

  private func isCompact(node: CanvasNodeCard) -> Bool {
    node.isAtMinimumSize
  }

  private var isResizingInteraction: Bool {
    if case .resizing = interaction { return true }
    return false
  }

  private func appendTerminalCard(at worldPoint: CGPoint, workingDirectory: String?, title: String) {
    let node = CanvasNodeCard.terminal(
      at: worldPoint,
      workingDirectory: workingDirectory,
      title: title
    )
    nodes.append(node)
    selectSingleNode(node.id)
  }

  private func appendFolderCard(at worldPoint: CGPoint, workingDirectory: String?, title: String?) {
    let node = CanvasNodeCard.folder(
      at: worldPoint,
      workingDirectory: workingDirectory,
      title: title
    )
    nodes.append(node)
    selectSingleNode(node.id)
  }

  private func switchContextCard(id: UUID, to kind: CanvasNodeKind) {
    guard let index = nodes.firstIndex(where: { $0.id == id }) else { return }
    nodes[index] = nodes[index].converted(to: kind)
    selectSingleNode(id)
  }

  private func finderPath(forNodeID id: UUID) -> String? {
    guard let node = nodes.first(where: { $0.id == id }) else { return nil }
    return InfiniteCanvasKit.finderOpenPath(for: node)
  }

  private func makeSnapshot() -> CanvasStateSnapshot {
    CanvasStateSnapshot(nodes: nodes, selectedNodeIDs: selectedNodeIDs, viewport: viewport)
  }

  private func scheduleAutosave() {
    guard !isRestoringState, autosaveKey != nil else { return }
    autosaveWorkItem?.cancel()
    let work = DispatchWorkItem { [weak self] in
      self?.persistNow()
    }
    autosaveWorkItem = work
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35, execute: work)
  }

  private func navigationDirection(from event: NSEvent) -> CanvasNavigationDirection? {
    switch event.keyCode {
    case 123: return .left
    case 124: return .right
    case 125: return .down
    case 126: return .up
    default: return nil
    }
  }

  private func navigateSelection(to direction: CanvasNavigationDirection) {
    let currentID = selectedNodeIDs.first
    guard let nextID = nextNodeID(from: currentID, direction: direction, in: nodes) else { return }
    selectSingleNode(nextID)
  }

  private func selectSingleNode(_ id: UUID) {
    guard nodes.contains(where: { $0.id == id }) else { return }
    let reordered = bringNodeToFront(id: id, in: nodes)
    if reordered != nodes {
      nodes = reordered
    }
    let nextSelection: Set<UUID> = [id]
    if selectedNodeIDs != nextSelection {
      selectedNodeIDs = nextSelection
    }
  }

  private func droppedDirectoryURLs(from pasteboard: NSPasteboard) -> [URL] {
    let options: [NSPasteboard.ReadingOptionKey: Any] = [
      .urlReadingFileURLsOnly: true,
    ]
    guard let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL] else {
      return []
    }

    return urls.filter { url in
      var isDirectory: ObjCBool = false
      guard FileManager.default.fileExists(atPath: url.path, isDirectory: &isDirectory) else { return false }
      return isDirectory.boolValue
    }
  }

  private func normalizedPhase(_ value: CGFloat, spacing: CGFloat) -> CGFloat {
    let mod = value.truncatingRemainder(dividingBy: spacing)
    return mod >= 0 ? mod : mod + spacing
  }
}
#endif
