import CoreGraphics
import Foundation

public struct CanvasNodeCard: Sendable, Equatable, Identifiable {
  public let id: UUID
  public var title: String
  public var position: CGPoint
  public var size: CGSize

  public init(
    id: UUID = UUID(),
    title: String = "Untitled",
    position: CGPoint,
    size: CGSize = CGSize(width: 280, height: 180)
  ) {
    self.id = id
    self.title = title
    self.position = position
    self.size = size
  }
}

public extension CanvasNodeCard {
  static let minimumSize = CGSize(width: 160, height: 120)

  var worldRect: CGRect {
    CGRect(origin: position, size: size)
  }

  mutating func translate(by delta: CGSize) {
    position.x += delta.width
    position.y += delta.height
  }

  mutating func resizeBy(delta: CGSize, minSize: CGSize = Self.minimumSize) {
    let nextWidth = max(minSize.width, size.width + delta.width)
    let nextHeight = max(minSize.height, size.height + delta.height)
    size = CGSize(width: nextWidth, height: nextHeight)
  }

  mutating func resize(
    using handle: CanvasNodeResizeHandle,
    delta: CGSize,
    minSize: CGSize = Self.minimumSize
  ) {
    var nextPosition = position
    var nextSize = size

    let dx = delta.width
    let dy = delta.height

    if handle.affectsLeft {
      let candidateWidth = nextSize.width - dx
      if candidateWidth >= minSize.width {
        nextPosition.x += dx
        nextSize.width = candidateWidth
      } else {
        nextPosition.x += nextSize.width - minSize.width
        nextSize.width = minSize.width
      }
    }

    if handle.affectsRight {
      nextSize.width = max(minSize.width, nextSize.width + dx)
    }

    if handle.affectsBottom {
      let candidateHeight = nextSize.height - dy
      if candidateHeight >= minSize.height {
        nextPosition.y += dy
        nextSize.height = candidateHeight
      } else {
        nextPosition.y += nextSize.height - minSize.height
        nextSize.height = minSize.height
      }
    }

    if handle.affectsTop {
      nextSize.height = max(minSize.height, nextSize.height + dy)
    }

    position = nextPosition
    size = nextSize
  }

  func intersects(_ worldSelectionRect: CGRect) -> Bool {
    worldRect.intersects(worldSelectionRect)
  }
}

public enum CanvasNodeResizeHandle: Sendable, Equatable, CaseIterable {
  case left
  case right
  case top
  case bottom
  case topLeft
  case topRight
  case bottomLeft
  case bottomRight

  var affectsLeft: Bool {
    self == .left || self == .topLeft || self == .bottomLeft
  }

  var affectsRight: Bool {
    self == .right || self == .topRight || self == .bottomRight
  }

  var affectsTop: Bool {
    self == .top || self == .topLeft || self == .topRight
  }

  var affectsBottom: Bool {
    self == .bottom || self == .bottomLeft || self == .bottomRight
  }
}

public func selectedNodeIDs(
  in worldSelectionRect: CGRect,
  from nodes: [CanvasNodeCard]
) -> Set<UUID> {
  Set(nodes.filter { $0.intersects(worldSelectionRect) }.map(\.id))
}

public struct InfiniteCanvasViewport: Sendable, Equatable {
  public private(set) var scale: CGFloat
  public private(set) var offset: CGPoint
  public let minScale: CGFloat
  public let maxScale: CGFloat

  public init(
    scale: CGFloat = 1,
    offset: CGPoint = .zero,
    minScale: CGFloat = 0.4,
    maxScale: CGFloat = 2.4
  ) {
    self.minScale = minScale
    self.maxScale = maxScale
    self.scale = max(min(scale, maxScale), minScale)
    self.offset = offset
  }

  public mutating func pan(by delta: CGSize) {
    offset.x += delta.width
    offset.y += delta.height
  }

  public mutating func zoom(
    multiplier: CGFloat,
    anchorInView anchor: CGPoint,
    viewportSize: CGSize
  ) {
    guard multiplier.isFinite, multiplier > 0 else { return }
    let previousScale = scale
    let previousWorld = viewToWorld(anchor, viewportSize: viewportSize)
    scale = max(min(previousScale * multiplier, maxScale), minScale)
    offset.x = anchor.x - viewportSize.width * 0.5 - previousWorld.x * scale
    offset.y = anchor.y - viewportSize.height * 0.5 - previousWorld.y * scale
  }

  public func worldToView(_ point: CGPoint, viewportSize: CGSize) -> CGPoint {
    CGPoint(
      x: viewportSize.width * 0.5 + offset.x + point.x * scale,
      y: viewportSize.height * 0.5 + offset.y + point.y * scale
    )
  }

  public func viewToWorld(_ point: CGPoint, viewportSize: CGSize) -> CGPoint {
    CGPoint(
      x: (point.x - viewportSize.width * 0.5 - offset.x) / scale,
      y: (point.y - viewportSize.height * 0.5 - offset.y) / scale
    )
  }
}
