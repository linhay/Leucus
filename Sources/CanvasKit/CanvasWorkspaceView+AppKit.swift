#if canImport(AppKit) && !canImport(UIKit)
import AppKit
import FolderCard
import InfiniteCanvasKit
import TerminalCard

@MainActor
@available(macOS 14.0, *)
public final class CanvasWorkspaceView: NSView {
  public let canvasView = InfiniteCanvasView()

  private let contentContainer = NSView()
  private let alignButton = NSButton(title: "对齐网格", target: nil, action: nil)
  private var terminalViews: [UUID: SimpleTerminalHostView] = [:]
  private var folderViews: [UUID: FolderBrowserHostView] = [:]
  private var detachedNodeIDs: Set<UUID> = []
  private var detachedWindows: [UUID: NSWindow] = [:]
  private var detachedWindowDelegates: [UUID: DetachedCanvasWindowDelegate] = [:]
  private var isResizingTerminalCard = false
  private var lastLayouts: [CanvasNodeLayout] = []

  public override init(frame frameRect: NSRect) {
    super.init(frame: frameRect)
    setup()
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    nil
  }

  public override func layout() {
    super.layout()
    canvasView.frame = bounds
    contentContainer.frame = bounds
    let buttonWidth: CGFloat = 96
    let buttonHeight: CGFloat = 30
    alignButton.frame = CGRect(
      x: bounds.maxX - buttonWidth - 16,
      y: 16,
      width: buttonWidth,
      height: buttonHeight
    )
  }

  private func setup() {
    wantsLayer = true
    contentContainer.wantsLayer = true
    contentContainer.layer?.backgroundColor = NSColor.clear.cgColor

    addSubview(canvasView)
    addSubview(contentContainer)
    addSubview(alignButton)

    canvasView.frame = bounds
    contentContainer.frame = bounds

    canvasView.onNodeLayoutsChanged = { [weak self] layouts in
      self?.syncCardContent(with: layouts)
    }
    canvasView.onResizeInteractionChanged = { [weak self] isResizing in
      self?.setTerminalResizeSuspended(isResizing)
    }
    canvasView.onDetachNodeRequested = { [weak self] nodeID in
      self?.presentDetachedWindow(for: nodeID)
    }

    alignButton.target = self
    alignButton.action = #selector(alignCardsToGridFromButton)
    alignButton.controlSize = .regular
    alignButton.toolTip = "将选中卡片对齐到网点网格（无选中时对齐全部）"
    CanvasAlignButtonStyle.apply(to: alignButton)
  }

  @objc
  private func alignCardsToGridFromButton() {
    window?.makeFirstResponder(canvasView)
    canvasView.alignSelectionToGrid()
  }

  private func syncCardContent(with layouts: [CanvasNodeLayout]) {
    lastLayouts = layouts
    pruneDetachedWindows()
    let activeLayouts = layouts.filter {
      ($0.kind == .terminal || $0.kind == .folder) &&
        !$0.isCompact &&
        $0.contentFrame.width >= 60 &&
        $0.contentFrame.height >= 44
    }
    let activeTerminalLayouts = activeLayouts.filter { $0.kind == .terminal }
    let activeFolderLayouts = activeLayouts.filter { $0.kind == .folder }

    let activeTerminalIDs = Set(activeTerminalLayouts.map(\.id))
    let activeFolderIDs = Set(activeFolderLayouts.map(\.id))

    for (id, view) in terminalViews where !activeTerminalIDs.contains(id) && !detachedNodeIDs.contains(id) {
      view.removeFromSuperview()
      terminalViews[id] = nil
    }

    for (id, view) in folderViews where !activeFolderIDs.contains(id) && !detachedNodeIDs.contains(id) {
      view.removeFromSuperview()
      folderViews[id] = nil
    }

    syncTerminalCards(activeTerminalLayouts)
    syncFolderCards(activeFolderLayouts)
    restackContentCards(activeLayouts)
  }

  private func syncTerminalCards(_ activeLayouts: [CanvasNodeLayout]) {
    if isResizingTerminalCard {
      for layout in activeLayouts {
        guard !detachedNodeIDs.contains(layout.id) else { continue }
        let terminalView = terminalView(for: layout)
        terminalView.isHidden = true
      }
      return
    }

    for layout in activeLayouts {
      guard !detachedNodeIDs.contains(layout.id) else { continue }
      let terminalView = terminalView(for: layout)
      let nextFrame = layout.contentFrame.integral
      let sizeChanged = terminalView.frame.size != nextFrame.size
      if terminalView.frame != nextFrame {
        terminalView.frame = nextFrame
      }
      if !isResizingTerminalCard && sizeChanged {
        terminalView.scheduleRefreshLayout()
      }
      terminalView.isHidden = false
    }
  }

  private func syncFolderCards(_ activeLayouts: [CanvasNodeLayout]) {
    for layout in activeLayouts {
      guard !detachedNodeIDs.contains(layout.id) else { continue }
      let folderView = folderView(for: layout)
      let nextFrame = layout.contentFrame.integral
      if folderView.frame != nextFrame {
        folderView.frame = nextFrame
      }
      folderView.setDirectoryPath(layout.workingDirectory, notifyChange: false)
      folderView.isHidden = false
    }
  }

  private func setTerminalResizeSuspended(_ suspended: Bool) {
    isResizingTerminalCard = suspended
    for terminalView in terminalViews.values {
      terminalView.isLayoutRefreshSuspended = suspended
      if suspended {
        terminalView.isHidden = true
      }
    }
    guard !suspended else { return }
    for terminalView in terminalViews.values {
      terminalView.isHidden = false
      terminalView.refreshLayout()
    }
    if !lastLayouts.isEmpty {
      syncCardContent(with: lastLayouts)
    }
  }

  private func terminalView(for layout: CanvasNodeLayout) -> SimpleTerminalHostView {
    if let existing = terminalViews[layout.id] {
      if existing.superview !== contentContainer {
        existing.removeFromSuperview()
        contentContainer.addSubview(existing)
      }
      configureTerminalHost(existing, nodeID: layout.id, detached: false)
      return existing
    }
    let terminal = SimpleTerminal(options: SimpleTerminalOptions(
      workingDirectory: layout.workingDirectory,
      title: layout.title
    ))
    let host = SimpleTerminalHostView(terminal: terminal)
    configureTerminalHost(host, nodeID: layout.id, detached: false)
    host.layer?.cornerRadius = 8
    host.layer?.masksToBounds = true
    contentContainer.addSubview(host)
    terminalViews[layout.id] = host
    return host
  }

  private func folderView(for layout: CanvasNodeLayout) -> FolderBrowserHostView {
    if let existing = folderViews[layout.id] {
      if existing.superview !== contentContainer {
        existing.removeFromSuperview()
        contentContainer.addSubview(existing)
      }
      configureFolderHost(existing, nodeID: layout.id, detached: false)
      return existing
    }

    let nodeID = layout.id
    let host = FolderBrowserHostView(directoryPath: layout.workingDirectory)
    configureFolderHost(host, nodeID: nodeID, detached: false)
    contentContainer.addSubview(host)
    folderViews[layout.id] = host
    return host
  }

  private func configureTerminalHost(_ host: SimpleTerminalHostView, nodeID: UUID, detached: Bool) {
    if detached {
      host.onScrollWheelPassthrough = nil
      host.onMagnifyPassthrough = nil
      host.onMouseDownInSurface = nil
      return
    }

    host.onScrollWheelPassthrough = { [weak self] event in
      self?.canvasView.scrollWheel(with: event)
    }
    host.onMagnifyPassthrough = { [weak self] event in
      self?.canvasView.magnify(with: event)
    }
    host.onMouseDownInSurface = { [weak self] in
      self?.canvasView.selectNode(id: nodeID)
    }
  }

  private func configureFolderHost(_ host: FolderBrowserHostView, nodeID: UUID, detached: Bool) {
    host.onDirectoryChanged = { [weak self] path, title in
      self?.updateFolderNode(id: nodeID, path: path, title: title)
      self?.detachedWindows[nodeID]?.title = title
    }

    if detached {
      host.onScrollWheelPassthrough = nil
      host.onMagnifyPassthrough = nil
      host.onInteraction = nil
      return
    }

    host.onScrollWheelPassthrough = { [weak self] event in
      self?.canvasView.scrollWheel(with: event)
    }
    host.onMagnifyPassthrough = { [weak self] event in
      self?.canvasView.magnify(with: event)
    }
    host.onInteraction = { [weak self] in
      self?.canvasView.selectNode(id: nodeID)
    }
  }

  private func updateFolderNode(id: UUID, path: String, title: String) {
    guard let index = canvasView.nodes.firstIndex(where: { $0.id == id }) else { return }
    var node = canvasView.nodes[index]
    guard node.kind == .folder else { return }
    guard node.workingDirectory != path || node.title != title else { return }

    node.workingDirectory = path
    node.title = title
    node = node.converted(to: .folder)
    canvasView.nodes[index] = node
  }

  private func restackContentCards(_ layouts: [CanvasNodeLayout]) {
    var previous: NSView?
    for layout in layouts {
      guard !detachedNodeIDs.contains(layout.id) else { continue }
      let view: NSView?
      switch layout.kind {
      case .terminal:
        view = terminalViews[layout.id]
      case .folder:
        view = folderViews[layout.id]
      case .placeholder:
        view = nil
      }
      guard let view else { continue }
      contentContainer.addSubview(view, positioned: .above, relativeTo: previous)
      previous = view
    }
  }

  private func presentDetachedWindow(for nodeID: UUID) {
    if let existing = detachedWindows[nodeID] {
      existing.makeKeyAndOrderFront(nil)
      NSApp.activate(ignoringOtherApps: true)
      return
    }

    guard let node = canvasView.nodes.first(where: { $0.id == nodeID }) else { return }
    guard node.kind == .terminal || node.kind == .folder else { return }

    let detachedView: NSView
    switch node.kind {
    case .terminal:
      let host = terminalHost(for: node)
      configureTerminalHost(host, nodeID: nodeID, detached: true)
      detachedView = host
    case .folder:
      let host = folderHost(for: node)
      configureFolderHost(host, nodeID: nodeID, detached: true)
      detachedView = host
    case .placeholder:
      return
    }

    detachedNodeIDs.insert(nodeID)
    detachedView.removeFromSuperview()

    let windowSize = CGSize(
      width: max(560, node.size.width),
      height: max(380, node.size.height)
    )
    let window = NSWindow(
      contentRect: CGRect(origin: .zero, size: windowSize),
      styleMask: [.titled, .closable, .resizable, .miniaturizable],
      backing: .buffered,
      defer: false
    )
    window.title = node.title
    window.minSize = CGSize(width: 320, height: 220)
    let container = NSView(frame: CGRect(origin: .zero, size: windowSize))
    detachedView.frame = container.bounds
    detachedView.autoresizingMask = [.width, .height]
    container.addSubview(detachedView)
    window.contentView = container
    window.center()
    window.isReleasedWhenClosed = false

    let delegate = DetachedCanvasWindowDelegate { [weak self] in
      self?.handleDetachedWindowClosed(nodeID: nodeID)
    }
    detachedWindows[nodeID] = window
    detachedWindowDelegates[nodeID] = delegate
    window.delegate = delegate

    window.makeKeyAndOrderFront(nil)
    NSApp.activate(ignoringOtherApps: true)
  }

  private func terminalHost(for node: CanvasNodeCard) -> SimpleTerminalHostView {
    if let existing = terminalViews[node.id] {
      return existing
    }
    let terminal = SimpleTerminal(options: SimpleTerminalOptions(
      workingDirectory: node.workingDirectory,
      title: node.title
    ))
    let host = SimpleTerminalHostView(terminal: terminal)
    host.layer?.cornerRadius = 8
    host.layer?.masksToBounds = true
    terminalViews[node.id] = host
    return host
  }

  private func folderHost(for node: CanvasNodeCard) -> FolderBrowserHostView {
    if let existing = folderViews[node.id] {
      return existing
    }
    let host = FolderBrowserHostView(directoryPath: node.workingDirectory)
    folderViews[node.id] = host
    return host
  }

  private func handleDetachedWindowClosed(nodeID: UUID) {
    defer {
      detachedWindows[nodeID] = nil
      detachedWindowDelegates[nodeID] = nil
    }

    guard canvasView.nodes.contains(where: { $0.id == nodeID }) else {
      detachedNodeIDs.remove(nodeID)
      terminalViews[nodeID]?.removeFromSuperview()
      folderViews[nodeID]?.removeFromSuperview()
      terminalViews[nodeID] = nil
      folderViews[nodeID] = nil
      return
    }

    detachedNodeIDs.remove(nodeID)

    if let terminalView = terminalViews[nodeID] {
      configureTerminalHost(terminalView, nodeID: nodeID, detached: false)
      terminalView.removeFromSuperview()
      contentContainer.addSubview(terminalView)
      terminalView.isHidden = false
      terminalView.refreshLayout()
    }

    if let folderView = folderViews[nodeID] {
      configureFolderHost(folderView, nodeID: nodeID, detached: false)
      folderView.removeFromSuperview()
      contentContainer.addSubview(folderView)
      folderView.isHidden = false
    }

    if !lastLayouts.isEmpty {
      syncCardContent(with: lastLayouts)
    }
  }

  private func pruneDetachedWindows() {
    let existingNodeIDs = Set(canvasView.nodes.map(\.id))
    for nodeID in Array(detachedWindows.keys) where !existingNodeIDs.contains(nodeID) {
      detachedWindows[nodeID]?.close()
      detachedWindows[nodeID] = nil
      detachedWindowDelegates[nodeID] = nil
      detachedNodeIDs.remove(nodeID)
    }
  }
}

@MainActor
private final class DetachedCanvasWindowDelegate: NSObject, NSWindowDelegate {
  private let onClose: () -> Void

  init(onClose: @escaping () -> Void) {
    self.onClose = onClose
  }

  func windowWillClose(_: Notification) {
    onClose()
  }
}
#endif
