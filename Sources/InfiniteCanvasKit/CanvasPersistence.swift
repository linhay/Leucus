import Foundation

public struct CanvasStateSnapshot: Codable, Equatable, Sendable {
  public struct Node: Codable, Equatable, Sendable {
    public let id: UUID
    public let kind: CanvasNodeKind
    public let group: CanvasNodeGroup
    public let groupLabel: String?
    public let title: String
    public let workingDirectory: String?
    public let x: Double
    public let y: Double
    public let width: Double
    public let height: Double
  }

  public struct Viewport: Codable, Equatable, Sendable {
    public let scale: Double
    public let offsetX: Double
    public let offsetY: Double
    public let minScale: Double
    public let maxScale: Double
  }

  public let nodes: [Node]
  public let selectedNodeIDs: [UUID]
  public let viewport: Viewport
}

public extension CanvasStateSnapshot {
  init(nodes: [CanvasNodeCard], selectedNodeIDs: Set<UUID>, viewport: InfiniteCanvasViewport) {
    self.nodes = nodes.map {
      Node(
        id: $0.id,
        kind: $0.kind,
        group: $0.group,
        groupLabel: $0.groupLabel,
        title: $0.title,
        workingDirectory: $0.workingDirectory,
        x: Double($0.position.x),
        y: Double($0.position.y),
        width: Double($0.size.width),
        height: Double($0.size.height)
      )
    }
    self.selectedNodeIDs = Array(selectedNodeIDs)
    self.viewport = Viewport(
      scale: Double(viewport.scale),
      offsetX: Double(viewport.offset.x),
      offsetY: Double(viewport.offset.y),
      minScale: Double(viewport.minScale),
      maxScale: Double(viewport.maxScale)
    )
  }

  func materializeNodes() -> [CanvasNodeCard] {
    nodes.map {
      CanvasNodeCard(
        id: $0.id,
        kind: $0.kind,
        group: $0.group,
        groupLabel: $0.groupLabel,
        title: $0.title,
        workingDirectory: $0.workingDirectory,
        position: CGPoint(x: $0.x, y: $0.y),
        size: CGSize(width: $0.width, height: $0.height)
      )
    }
  }

  func materializeViewport() -> InfiniteCanvasViewport {
    InfiniteCanvasViewport(
      scale: viewport.scale,
      offset: CGPoint(x: viewport.offsetX, y: viewport.offsetY),
      minScale: viewport.minScale,
      maxScale: viewport.maxScale
    )
  }
}

public enum CanvasSnapshotStore {
  public static func defaultURL(for key: String) -> URL {
    let fm = FileManager.default
    let base = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
      ?? fm.temporaryDirectory
    let dir = base.appendingPathComponent("CanvasTerminalKit/CanvasSnapshots", isDirectory: true)
    return dir.appendingPathComponent("\(key).json")
  }

  @discardableResult
  public static func save(_ snapshot: CanvasStateSnapshot, key: String) -> Bool {
    save(snapshot, to: defaultURL(for: key))
  }

  @discardableResult
  public static func save(_ snapshot: CanvasStateSnapshot, to url: URL) -> Bool {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.prettyPrinted, .sortedKeys]

    do {
      let data = try encoder.encode(snapshot)
      let parent = url.deletingLastPathComponent()
      try FileManager.default.createDirectory(at: parent, withIntermediateDirectories: true)
      try data.write(to: url, options: .atomic)
      return true
    } catch {
      return false
    }
  }

  public static func load(key: String) -> CanvasStateSnapshot? {
    load(from: defaultURL(for: key))
  }

  public static func load(from url: URL) -> CanvasStateSnapshot? {
    do {
      let data = try Data(contentsOf: url)
      return try JSONDecoder().decode(CanvasStateSnapshot.self, from: data)
    } catch {
      return nil
    }
  }
}
