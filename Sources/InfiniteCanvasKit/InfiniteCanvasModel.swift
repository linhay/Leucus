import CoreGraphics
import Foundation

public enum CanvasNodeKind: String, Sendable, Equatable, Codable {
  case placeholder
  case terminal
}

public enum CanvasNodeGroup: String, Sendable, Equatable, Codable {
  case folder
  case unknown
}

public struct CanvasNodeCard: Sendable, Equatable, Identifiable {
  public let id: UUID
  public var kind: CanvasNodeKind
  public var group: CanvasNodeGroup
  public var groupLabel: String?
  public var title: String
  public var workingDirectory: String?
  public var position: CGPoint
  public var size: CGSize

  public init(
    id: UUID = UUID(),
    kind: CanvasNodeKind = .placeholder,
    group: CanvasNodeGroup = .unknown,
    groupLabel: String? = nil,
    title: String = "Untitled",
    workingDirectory: String? = nil,
    position: CGPoint,
    size: CGSize = CGSize(width: 280, height: 180)
  ) {
    self.id = id
    self.kind = kind
    self.group = group
    self.groupLabel = groupLabel
    self.title = title
    self.workingDirectory = workingDirectory
    self.position = position
    self.size = size
  }
}

public struct CanvasNodeLayout: Sendable, Equatable {
  public var id: UUID
  public var kind: CanvasNodeKind
  public var title: String
  public var workingDirectory: String?
  public var frame: CGRect
  public var contentFrame: CGRect
  public var isCompact: Bool

  public init(
    id: UUID,
    kind: CanvasNodeKind,
    title: String,
    workingDirectory: String?,
    frame: CGRect,
    contentFrame: CGRect,
    isCompact: Bool
  ) {
    self.id = id
    self.kind = kind
    self.title = title
    self.workingDirectory = workingDirectory
    self.frame = frame
    self.contentFrame = contentFrame
    self.isCompact = isCompact
  }
}

public extension CanvasNodeCard {
  static let minimumSize = CGSize(width: 160, height: 120)
  private static let minimumEpsilon: CGFloat = 0.001

  var isAtMinimumSize: Bool {
    size.width <= Self.minimumSize.width + Self.minimumEpsilon
      && size.height <= Self.minimumSize.height + Self.minimumEpsilon
  }

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

  static func terminal(
    at position: CGPoint,
    workingDirectory: String? = nil,
    title: String = "Terminal",
    size: CGSize = CGSize(width: 320, height: 220)
  ) -> CanvasNodeCard {
    let groupLabel = folderMajorCategory(from: workingDirectory)
    return CanvasNodeCard(
      kind: .terminal,
      group: .folder,
      groupLabel: groupLabel,
      title: title,
      workingDirectory: workingDirectory,
      position: position,
      size: size
    )
  }

  private static func folderMajorCategory(from workingDirectory: String?) -> String {
    guard let workingDirectory, !workingDirectory.isEmpty else {
      return "未指定"
    }

    let url = URL(fileURLWithPath: workingDirectory)
    let components = url.pathComponents.filter { $0 != "/" }
    if components.isEmpty {
      return "根目录"
    }

    if components.first == "Users", components.count >= 3 {
      return components[2]
    }

    return components.first ?? "未指定"
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

public enum CanvasNodeResizeGeometry {
  public static func hitHandle(
    at point: CGPoint,
    in rect: CGRect,
    handleVisualSize: CGFloat,
    edgeHitWidth: CGFloat
  ) -> CanvasNodeResizeHandle? {
    for (handle, hitRect) in cornerHitRects(for: rect, handleVisualSize: handleVisualSize) {
      if hitRect.contains(point) { return handle }
    }
    for (handle, hitRect) in edgeHitRects(
      for: rect,
      handleVisualSize: handleVisualSize,
      edgeHitWidth: edgeHitWidth
    ) {
      if hitRect.contains(point) { return handle }
    }
    return nil
  }

  public static func cornerHitRects(
    for rect: CGRect,
    handleVisualSize: CGFloat
  ) -> [(CanvasNodeResizeHandle, CGRect)] {
    let s = max(14, handleVisualSize * 1.8)
    let hs = s * 0.5
    return [
      (.topLeft, CGRect(x: rect.minX - hs, y: rect.maxY - hs, width: s, height: s)),
      (.topRight, CGRect(x: rect.maxX - hs, y: rect.maxY - hs, width: s, height: s)),
      (.bottomLeft, CGRect(x: rect.minX - hs, y: rect.minY - hs, width: s, height: s)),
      (.bottomRight, CGRect(x: rect.maxX - hs, y: rect.minY - hs, width: s, height: s)),
    ]
  }

  public static func edgeHitRects(
    for rect: CGRect,
    handleVisualSize: CGFloat,
    edgeHitWidth: CGFloat
  ) -> [(CanvasNodeResizeHandle, CGRect)] {
    let inset = max(12, handleVisualSize * 1.5)
    let w = edgeHitWidth
    return [
      (.top, CGRect(x: rect.minX + inset, y: rect.maxY - w * 0.5, width: max(0, rect.width - inset * 2), height: w)),
      (.bottom, CGRect(x: rect.minX + inset, y: rect.minY - w * 0.5, width: max(0, rect.width - inset * 2), height: w)),
      (.left, CGRect(x: rect.minX - w * 0.5, y: rect.minY + inset, width: w, height: max(0, rect.height - inset * 2))),
      (.right, CGRect(x: rect.maxX - w * 0.5, y: rect.minY + inset, width: w, height: max(0, rect.height - inset * 2))),
    ]
  }

  public static func highlightRects(
    for handle: CanvasNodeResizeHandle,
    in rect: CGRect,
    thickness: CGFloat = 2
  ) -> [CGRect] {
    let line = max(1, thickness)
    let top = CGRect(x: rect.minX, y: rect.maxY - line, width: rect.width, height: line)
    let bottom = CGRect(x: rect.minX, y: rect.minY, width: rect.width, height: line)
    let left = CGRect(x: rect.minX, y: rect.minY, width: line, height: rect.height)
    let right = CGRect(x: rect.maxX - line, y: rect.minY, width: line, height: rect.height)

    switch handle {
    case .top:
      return [top]
    case .bottom:
      return [bottom]
    case .left:
      return [left]
    case .right:
      return [right]
    case .topLeft:
      return [top, left]
    case .topRight:
      return [top, right]
    case .bottomLeft:
      return [bottom, left]
    case .bottomRight:
      return [bottom, right]
    }
  }
}

public enum CanvasNavigationDirection: Sendable, Equatable {
  case up
  case down
  case left
  case right
}

public func nextNodeID(
  from currentID: UUID?,
  direction: CanvasNavigationDirection,
  in nodes: [CanvasNodeCard]
) -> UUID? {
  guard !nodes.isEmpty else { return nil }

  guard
    let currentID,
    let current = nodes.first(where: { $0.id == currentID })
  else {
    return nodes.first?.id
  }

  let currentCenter = CGPoint(x: current.position.x + current.size.width * 0.5, y: current.position.y + current.size.height * 0.5)

  let candidates = nodes.filter { $0.id != currentID }.compactMap { node -> (id: UUID, primary: CGFloat, secondary: CGFloat, distance: CGFloat)? in
    let center = CGPoint(x: node.position.x + node.size.width * 0.5, y: node.position.y + node.size.height * 0.5)
    let dx = center.x - currentCenter.x
    let dy = center.y - currentCenter.y

    switch direction {
    case .left:
      guard dx < 0 else { return nil }
      return (node.id, -dx, abs(dy), hypot(dx, dy))
    case .right:
      guard dx > 0 else { return nil }
      return (node.id, dx, abs(dy), hypot(dx, dy))
    case .up:
      guard dy > 0 else { return nil }
      return (node.id, dy, abs(dx), hypot(dx, dy))
    case .down:
      guard dy < 0 else { return nil }
      return (node.id, -dy, abs(dx), hypot(dx, dy))
    }
  }

  guard !candidates.isEmpty else { return currentID }
  return candidates.min {
    if $0.primary != $1.primary { return $0.primary < $1.primary }
    if $0.secondary != $1.secondary { return $0.secondary < $1.secondary }
    return $0.distance < $1.distance
  }?.id
}

public func selectedNodeIDs(
  in worldSelectionRect: CGRect,
  from nodes: [CanvasNodeCard]
) -> Set<UUID> {
  Set(nodes.filter { $0.intersects(worldSelectionRect) }.map(\.id))
}

public func finderOpenPath(for node: CanvasNodeCard) -> String? {
  switch node.kind {
  case .terminal:
    guard let path = node.workingDirectory, !path.isEmpty else { return nil }
    return path
  case .placeholder:
    return nil
  }
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
