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
  }

  private func syncTerminalCards(with layouts: [CanvasNodeLayout]) {
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

    for layout in activeLayouts {
      let terminalView = terminalView(for: layout)
      terminalView.frame = layout.contentFrame
      terminalView.isHidden = false
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
    host.layer?.cornerRadius = 8
    host.layer?.masksToBounds = true
    terminalContainer.addSubview(host)
    terminalViews[layout.id] = host
    return host
  }
}
#endif
