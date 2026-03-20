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
  private var terminalViews: [UUID: SimpleTerminalHostView] = [:]
  private var folderViews: [UUID: FolderBrowserHostView] = [:]
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
  }

  private func setup() {
    wantsLayer = true
    contentContainer.wantsLayer = true
    contentContainer.layer?.backgroundColor = NSColor.clear.cgColor

    addSubview(canvasView)
    addSubview(contentContainer)

    canvasView.frame = bounds
    contentContainer.frame = bounds

    canvasView.onNodeLayoutsChanged = { [weak self] layouts in
      self?.syncCardContent(with: layouts)
    }
    canvasView.onResizeInteractionChanged = { [weak self] isResizing in
      self?.setTerminalResizeSuspended(isResizing)
    }
  }

  private func syncCardContent(with layouts: [CanvasNodeLayout]) {
    lastLayouts = layouts
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

    for (id, view) in terminalViews where !activeTerminalIDs.contains(id) {
      view.removeFromSuperview()
      terminalViews[id] = nil
    }

    for (id, view) in folderViews where !activeFolderIDs.contains(id) {
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
        let terminalView = terminalView(for: layout)
        terminalView.isHidden = true
      }
      return
    }

    for layout in activeLayouts {
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
      return existing
    }
    let terminal = SimpleTerminal(options: SimpleTerminalOptions(
      workingDirectory: layout.workingDirectory,
      title: layout.title
    ))
    let host = SimpleTerminalHostView(terminal: terminal)
    host.onScrollWheelPassthrough = { [weak self] event in
      self?.canvasView.scrollWheel(with: event)
    }
    host.onMagnifyPassthrough = { [weak self] event in
      self?.canvasView.magnify(with: event)
    }
    host.onMouseDownInSurface = { [weak self] in
      self?.canvasView.selectNode(id: layout.id)
    }
    host.layer?.cornerRadius = 8
    host.layer?.masksToBounds = true
    contentContainer.addSubview(host)
    terminalViews[layout.id] = host
    return host
  }

  private func folderView(for layout: CanvasNodeLayout) -> FolderBrowserHostView {
    if let existing = folderViews[layout.id] {
      return existing
    }

    let nodeID = layout.id
    let host = FolderBrowserHostView(directoryPath: layout.workingDirectory)
    host.onScrollWheelPassthrough = { [weak self] event in
      self?.canvasView.scrollWheel(with: event)
    }
    host.onMagnifyPassthrough = { [weak self] event in
      self?.canvasView.magnify(with: event)
    }
    host.onInteraction = { [weak self] in
      self?.canvasView.selectNode(id: nodeID)
    }
    host.onDirectoryChanged = { [weak self] path, title in
      self?.updateFolderNode(id: nodeID, path: path, title: title)
    }
    contentContainer.addSubview(host)
    folderViews[layout.id] = host
    return host
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
}
#endif
