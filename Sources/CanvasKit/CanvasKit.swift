@_exported import InfiniteCanvasKit
@_exported import TerminalCard

public enum CanvasKit {
  public static let version = "0.1.0"
}

public typealias InfiniteCanvasViewport = InfiniteCanvasKit.InfiniteCanvasViewport
public typealias CanvasNodeCard = InfiniteCanvasKit.CanvasNodeCard
public typealias SimpleTerminal = TerminalCard.SimpleTerminal
public typealias SimpleTerminalOptions = TerminalCard.SimpleTerminalOptions

#if canImport(AppKit) && !canImport(UIKit)
public typealias InfiniteCanvasView = InfiniteCanvasKit.InfiniteCanvasView
#endif
