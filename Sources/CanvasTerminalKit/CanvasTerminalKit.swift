import GhosttyTerminal
import SwiftUI

public enum CanvasTerminalKit {
  public static let version = "0.2.4"
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
public final class SimpleTerminal {
  public let state: TerminalViewState
  public let title: String

  public init(
    options: SimpleTerminalOptions = .init(),
    theme: TerminalTheme = .default,
    terminalConfiguration: TerminalConfiguration = .default
  ) {
    title = options.title
    state = TerminalViewState(
      theme: theme,
      terminalConfiguration: terminalConfiguration
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

  public init(terminal: SimpleTerminal = .init()) {
    self.terminal = terminal
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
private struct SimpleTerminalPlatformView: NSViewRepresentable {
  let terminal: SimpleTerminal

  func makeNSView(context _: Context) -> TerminalView {
    let view = TerminalView(frame: .zero)
    configure(view)
    return view
  }

  func updateNSView(_ view: TerminalView, context _: Context) {
    configure(view)
  }

  private func configure(_ view: TerminalView) {
    view.delegate = terminal.state
    view.configuration = terminal.state.configuration
    if view.controller !== terminal.state.controller {
      view.controller = terminal.state.controller
    }
    DispatchQueue.main.async {
      view.fitToSize()
      if view.window?.firstResponder !== view {
        _ = view.window?.makeFirstResponder(view)
      }
    }
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
