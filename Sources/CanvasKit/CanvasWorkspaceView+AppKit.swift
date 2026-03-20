#if canImport(AppKit) && !canImport(UIKit)
import AppKit
import InfiniteCanvasKit
import TerminalCard

@MainActor
@available(macOS 14.0, *)
public final class CanvasWorkspaceView: NSView {
  public let canvasView = InfiniteCanvasView()

  private let terminalContainer = NSView()
  private var terminalViews: [UUID: SimpleTerminalHostView] = [:]
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
    terminalContainer.frame = bounds
  }

  private func setup() {
    wantsLayer = true
    terminalContainer.wantsLayer = true
    terminalContainer.layer?.backgroundColor = NSColor.clear.cgColor

    addSubview(canvasView)
    addSubview(terminalContainer)

    canvasView.frame = bounds
    terminalContainer.frame = bounds

    canvasView.onNodeLayoutsChanged = { [weak self] layouts in
      self?.syncTerminalCards(with: layouts)
    }
    canvasView.onResizeInteractionChanged = { [weak self] isResizing in
      self?.setTerminalResizeSuspended(isResizing)
    }
  }

  private func syncTerminalCards(with layouts: [CanvasNodeLayout]) {
    lastLayouts = layouts
    let activeLayouts = layouts.filter {
      $0.kind == .terminal &&
        !$0.isCompact &&
        $0.contentFrame.width >= 60 &&
        $0.contentFrame.height >= 44
    }
    let activeIDs = Set(activeLayouts.map(\.id))

    for (id, view) in terminalViews where !activeIDs.contains(id) {
      view.removeFromSuperview()
      terminalViews[id] = nil
    }

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
      syncTerminalCards(with: lastLayouts)
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
    host.layer?.cornerRadius = 8
    host.layer?.masksToBounds = true
    terminalContainer.addSubview(host)
    terminalViews[layout.id] = host
    return host
  }
}
#endif
