import GhosttyKit
import GhosttyTerminal
import SwiftUI

public enum TerminalCardInfo {
  public static let version = "0.1.0"
}

public struct SimpleTerminalOptions: Sendable, Equatable {
  public var workingDirectory: String?
  public var fontSize: Float?
  public var title: String

  public init(
    workingDirectory: String? = nil,
    fontSize: Float? = nil,
    title: String = "Terminal"
  ) {
    self.workingDirectory = workingDirectory
    self.fontSize = fontSize
    self.title = title
  }
}

@MainActor
private final class SimpleTerminalRuntimeStore {
  static let shared = SimpleTerminalRuntimeStore()
  let runtime = GhosttyRuntime()

  private init() {}
}

@MainActor
public final class SimpleTerminal {
  public let state: TerminalViewState
  public let title: String
  let runtime: GhosttyRuntime

  public init(
    options: SimpleTerminalOptions = .init(),
    theme: TerminalTheme = .default,
    terminalConfiguration: TerminalConfiguration = .default
  ) {
    title = options.title
    runtime = SimpleTerminalRuntimeStore.shared.runtime
    state = TerminalViewState(
      theme: theme,
      terminalConfiguration: terminalConfiguration.backgroundOpacity(1)
    )
    state.configuration = TerminalSurfaceOptions(
      backend: .exec,
      fontSize: options.fontSize,
      workingDirectory: options.workingDirectory,
      context: .window
    )
  }
}

@MainActor
@available(macOS 14.0, iOS 17.0, macCatalyst 17.0, *)
public struct SimpleTerminalView: View {
  private let terminal: SimpleTerminal

  public init(terminal: SimpleTerminal? = nil) {
    self.terminal = terminal ?? .init()
  }

  public var body: some View {
    SimpleTerminalPlatformView(terminal: terminal)
      .background(.clear)
  }
}

#if canImport(AppKit) && !canImport(UIKit)
import AppKit

@MainActor
@available(macOS 14.0, *)
public final class SimpleTerminalHostView: NSView {
  public let terminal: SimpleTerminal
  private let surfaceView: GhosttySurfaceView
  private let surfaceWrapper: GhosttySurfaceScrollView
  private var lastRefreshSize: CGSize = .zero
  private var pendingRefreshWorkItem: DispatchWorkItem?
  public var isLayoutRefreshSuspended = false

  public init(terminal: SimpleTerminal? = nil) {
    let resolvedTerminal = terminal ?? .init()
    self.terminal = resolvedTerminal

    let workingDirectoryURL: URL?
    if let workingDirectory = resolvedTerminal.state.configuration.workingDirectory,
      !workingDirectory.isEmpty
    {
      workingDirectoryURL = URL(fileURLWithPath: workingDirectory, isDirectory: true)
    } else {
      workingDirectoryURL = nil
    }

    surfaceView = GhosttySurfaceView(
      runtime: resolvedTerminal.runtime,
      workingDirectory: workingDirectoryURL,
      initialInput: nil,
      fontSize: resolvedTerminal.state.configuration.fontSize,
      context: GHOSTTY_SURFACE_CONTEXT_WINDOW
    )
    surfaceWrapper = GhosttySurfaceScrollView(surfaceView: surfaceView)

    super.init(frame: .zero)
    wantsLayer = true
    layer?.masksToBounds = true
    addSubview(surfaceWrapper)
  }

  @available(*, unavailable)
  required init?(coder: NSCoder) {
    nil
  }

  public override func viewDidMoveToWindow() {
    super.viewDidMoveToWindow()
    surfaceView.requestFocus()
  }

  public override func layout() {
    super.layout()
    guard bounds.size != lastRefreshSize else { return }
    guard !isLayoutRefreshSuspended else {
      pendingRefreshWorkItem?.cancel()
      pendingRefreshWorkItem = nil
      lastRefreshSize = bounds.size
      surfaceWrapper.frame = bounds
      surfaceWrapper.pinnedSize = bounds.size
      surfaceWrapper.needsLayout = true
      return
    }
    scheduleRefreshLayout()
  }

  public func refreshLayout() {
    pendingRefreshWorkItem?.cancel()
    pendingRefreshWorkItem = nil
    applyRefreshLayout()
  }

  public func scheduleRefreshLayout() {
    pendingRefreshWorkItem?.cancel()
    let workItem = DispatchWorkItem { [weak self] in
      self?.applyRefreshLayout()
    }
    pendingRefreshWorkItem = workItem
    DispatchQueue.main.async(execute: workItem)
  }

  private func applyRefreshLayout() {
    lastRefreshSize = bounds.size
    surfaceWrapper.frame = bounds
    surfaceWrapper.pinnedSize = bounds.size
    surfaceWrapper.needsLayout = true
    surfaceWrapper.layoutSubtreeIfNeeded()
    surfaceWrapper.updateSurfaceSize()
  }
}

@MainActor
@available(macOS 14.0, *)
private struct SimpleTerminalPlatformView: NSViewRepresentable {
  let terminal: SimpleTerminal

  func makeNSView(context _: Context) -> SimpleTerminalHostView {
    SimpleTerminalHostView(terminal: terminal)
  }

  func updateNSView(_ view: SimpleTerminalHostView, context _: Context) {
    view.refreshLayout()
  }
}
#elseif canImport(UIKit)
import UIKit

@MainActor
@available(iOS 17.0, macCatalyst 17.0, *)
private struct SimpleTerminalPlatformView: UIViewRepresentable {
  let terminal: SimpleTerminal

  func makeUIView(context _: Context) -> TerminalView {
    let view = TerminalView(frame: .zero)
    configure(view)
    focusAndFit(view)
    return view
  }

  func updateUIView(_ view: TerminalView, context _: Context) {
    configure(view)
    focusAndFit(view)
  }

  private func configure(_ view: TerminalView) {
    view.delegate = terminal.state
    view.configuration = terminal.state.configuration
    if view.controller !== terminal.state.controller {
      view.controller = terminal.state.controller
    }
  }

  private func focusAndFit(_ view: TerminalView) {
    DispatchQueue.main.async {
      view.fitToSize()
      _ = view.becomeFirstResponder()
    }
  }
}
#endif
