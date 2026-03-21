import Foundation
import Vapor

public struct CardControlRouteRequest: Content, Sendable, Equatable {
  public var sourceCardID: UUID?
  public var metadata: [String: String]?

  public init(sourceCardID: UUID? = nil, metadata: [String: String]? = nil) {
    self.sourceCardID = sourceCardID
    self.metadata = metadata
  }
}

public struct CardControlRouteValueRequest: Content, Sendable, Equatable {
  public var sourceCardID: UUID?
  public var value: String
  public var metadata: [String: String]?

  public init(
    sourceCardID: UUID? = nil,
    value: String,
    metadata: [String: String]? = nil
  ) {
    self.sourceCardID = sourceCardID
    self.value = value
    self.metadata = metadata
  }
}

public struct CardControlCommandRequest: Content, Sendable, Equatable {
  public var sourceCardID: UUID?
  public var targetCardID: UUID
  public var action: String
  public var value: String?
  public var metadata: [String: String]?

  public init(
    sourceCardID: UUID?,
    targetCardID: UUID,
    action: String,
    value: String?,
    metadata: [String: String]?
  ) {
    self.sourceCardID = sourceCardID
    self.targetCardID = targetCardID
    self.action = action
    self.value = value
    self.metadata = metadata
  }
}

public struct CardControlCommand: Content, Sendable, Equatable {
  public var spaceID: UUID
  public var sourceCardID: UUID?
  public var targetCardID: UUID
  public var action: String
  public var value: String?
  public var metadata: [String: String]?
  public var issuedAt: Date

  public init(
    spaceID: UUID = CardCommandCenter.defaultSpaceID,
    sourceCardID: UUID?,
    targetCardID: UUID,
    action: String,
    value: String?,
    metadata: [String: String]?,
    issuedAt: Date = Date()
  ) {
    self.spaceID = spaceID
    self.sourceCardID = sourceCardID
    self.targetCardID = targetCardID
    self.action = action
    self.value = value
    self.metadata = metadata
    self.issuedAt = issuedAt
  }

  public init(
    sourceCardID: UUID?,
    targetCardID: UUID,
    action: String,
    value: String?,
    metadata: [String: String]?,
    issuedAt: Date = Date()
  ) {
    self.init(
      spaceID: CardCommandCenter.defaultSpaceID,
      sourceCardID: sourceCardID,
      targetCardID: targetCardID,
      action: action,
      value: value,
      metadata: metadata,
      issuedAt: issuedAt
    )
  }

}

public struct CardRouteActionDescriptor: Content, Sendable, Equatable {
  public var action: String
  public var method: String
  public var pathTemplate: String
  public var mappedCommandAction: String
  public var requiresValue: Bool
  public var scope: String

  public init(
    action: String,
    method: String,
    pathTemplate: String,
    mappedCommandAction: String,
    requiresValue: Bool,
    scope: String
  ) {
    self.action = action
    self.method = method
    self.pathTemplate = pathTemplate
    self.mappedCommandAction = mappedCommandAction
    self.requiresValue = requiresValue
    self.scope = scope
  }
}

public struct CardRouteDiscoveryResponse: Content, Sendable, Equatable {
  public var spaceID: UUID
  public var cardID: UUID
  public var routes: [CardRouteActionDescriptor]

  public init(spaceID: UUID, cardID: UUID, routes: [CardRouteActionDescriptor]) {
    self.spaceID = spaceID
    self.cardID = cardID
    self.routes = routes
  }

}

public actor CardCommandCenter {
  public static let defaultSpaceID = UUID(uuidString: "00000000-0000-0000-0000-000000000000")!

  private struct QueueKey: Hashable {
    let spaceID: UUID
    let cardID: UUID
  }

  private var queues: [QueueKey: [CardControlCommand]] = [:]

  public init() {}

  public func enqueue(_ command: CardControlCommand) {
    let key = QueueKey(spaceID: command.spaceID, cardID: command.targetCardID)
    queues[key, default: []].append(command)
  }

  public func drainCommands(for spaceID: UUID, targetCardID: UUID, limit: Int = 50) -> [CardControlCommand] {
    let safeLimit = max(1, limit)
    let key = QueueKey(spaceID: spaceID, cardID: targetCardID)
    let commands = queues[key, default: []]
    let drained = Array(commands.prefix(safeLimit))
    queues[key] = Array(commands.dropFirst(drained.count))
    return drained
  }

  public func drainCommands(for targetCardID: UUID, limit: Int = 50) -> [CardControlCommand] {
    drainCommands(for: Self.defaultSpaceID, targetCardID: targetCardID, limit: limit)
  }

}

public enum CardHubVapor {
  public static let defaultSpaceID = CardCommandCenter.defaultSpaceID

  private static func cardID(from req: Request) throws -> UUID {
    guard let cardIDString = req.parameters.get("cardID"), let cardID = UUID(uuidString: cardIDString) else {
      throw Abort(.badRequest, reason: "cardID 非法")
    }
    return cardID
  }

  private static func spaceID(from req: Request) throws -> UUID {
    guard let spaceIDString = req.parameters.get("spaceID"), let spaceID = UUID(uuidString: spaceIDString) else {
      throw Abort(.badRequest, reason: "spaceID 非法")
    }
    return spaceID
  }

  private static func enqueue(
    center: CardCommandCenter,
    spaceID: UUID,
    targetCardID: UUID,
    action: String,
    sourceCardID: UUID?,
    value: String?,
    metadata: [String: String]?
  ) async {
    let command = CardControlCommand(
      spaceID: spaceID,
      sourceCardID: sourceCardID,
      targetCardID: targetCardID,
      action: action,
      value: value,
      metadata: metadata
    )
    await center.enqueue(command)
  }

  private static func handleActionRoute(
    req: Request,
    center: CardCommandCenter,
    spaceID: UUID,
    mappedAction: String,
    requiresValue: Bool,
    valueFieldName: String
  ) async throws -> HTTPStatus {
    let targetCardID = try cardID(from: req)

    if requiresValue {
      let payload = try req.content.decode(CardControlRouteValueRequest.self)
      let value = payload.value.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !value.isEmpty else {
        throw Abort(.badRequest, reason: "\(valueFieldName) 不能为空")
      }
      await enqueue(
        center: center,
        spaceID: spaceID,
        targetCardID: targetCardID,
        action: mappedAction,
        sourceCardID: payload.sourceCardID,
        value: value,
        metadata: payload.metadata
      )
      return .accepted
    }

    let payload = (try? req.content.decode(CardControlRouteRequest.self)) ?? .init()
    await enqueue(
      center: center,
      spaceID: spaceID,
      targetCardID: targetCardID,
      action: mappedAction,
      sourceCardID: payload.sourceCardID,
      value: nil,
      metadata: payload.metadata
    )
    return .accepted
  }

  public static let routeDescriptors: [CardRouteActionDescriptor] = [
    .init(
      action: "select",
      method: "POST",
      pathTemplate: "/api/v1/spaces/:spaceID/cards/:cardID/actions/select",
      mappedCommandAction: "select",
      requiresValue: false,
      scope: "all"
    ),
    .init(
      action: "close",
      method: "POST",
      pathTemplate: "/api/v1/spaces/:spaceID/cards/:cardID/actions/close",
      mappedCommandAction: "close",
      requiresValue: false,
      scope: "all"
    ),
    .init(
      action: "title",
      method: "POST",
      pathTemplate: "/api/v1/spaces/:spaceID/cards/:cardID/actions/title",
      mappedCommandAction: "set-title",
      requiresValue: true,
      scope: "all"
    ),
    .init(
      action: "url",
      method: "POST",
      pathTemplate: "/api/v1/spaces/:spaceID/cards/:cardID/actions/url",
      mappedCommandAction: "set-url",
      requiresValue: true,
      scope: "web"
    ),
    .init(
      action: "directory",
      method: "POST",
      pathTemplate: "/api/v1/spaces/:spaceID/cards/:cardID/actions/directory",
      mappedCommandAction: "set-directory",
      requiresValue: true,
      scope: "terminal|folder"
    ),
  ]

  public static func configure(_ app: Application, center: CardCommandCenter) throws {
    app.get("api", "v1", "health") { _ in
      ["status": "ok"]
    }

    app.post("api", "v1", "spaces", ":spaceID", "commands") { req async throws -> HTTPStatus in
      let spaceID = try spaceID(from: req)
      let payload = try req.content.decode(CardControlCommandRequest.self)
      let action = payload.action.trimmingCharacters(in: .whitespacesAndNewlines)
      guard !action.isEmpty else {
        throw Abort(.badRequest, reason: "action 不能为空")
      }
      let command = CardControlCommand(
        spaceID: spaceID,
        sourceCardID: payload.sourceCardID,
        targetCardID: payload.targetCardID,
        action: action,
        value: payload.value,
        metadata: payload.metadata
      )
      await center.enqueue(command)
      return .accepted
    }

    app.get("api", "v1", "spaces", ":spaceID", "cards", ":cardID", "commands") { req async throws -> [CardControlCommand] in
      let spaceID = try spaceID(from: req)
      let cardID = try cardID(from: req)
      let limit = (try? req.query.get(Int.self, at: "limit")) ?? 50
      return await center.drainCommands(for: spaceID, targetCardID: cardID, limit: limit)
    }

    app.get("api", "v1", "spaces", ":spaceID", "cards", ":cardID", "routes") { req async throws -> CardRouteDiscoveryResponse in
      let spaceID = try spaceID(from: req)
      let cardID = try cardID(from: req)
      return CardRouteDiscoveryResponse(spaceID: spaceID, cardID: cardID, routes: routeDescriptors)
    }

    // Canonical action routes.
    app.post("api", "v1", "spaces", ":spaceID", "cards", ":cardID", "actions", "select") { req async throws -> HTTPStatus in
      let spaceID = try spaceID(from: req)
      return try await handleActionRoute(
        req: req,
        center: center,
        spaceID: spaceID,
        mappedAction: "select",
        requiresValue: false,
        valueFieldName: "value"
      )
    }

    app.post("api", "v1", "spaces", ":spaceID", "cards", ":cardID", "actions", "close") { req async throws -> HTTPStatus in
      let spaceID = try spaceID(from: req)
      return try await handleActionRoute(
        req: req,
        center: center,
        spaceID: spaceID,
        mappedAction: "close",
        requiresValue: false,
        valueFieldName: "value"
      )
    }

    app.post("api", "v1", "spaces", ":spaceID", "cards", ":cardID", "actions", "title") { req async throws -> HTTPStatus in
      let spaceID = try spaceID(from: req)
      return try await handleActionRoute(
        req: req,
        center: center,
        spaceID: spaceID,
        mappedAction: "set-title",
        requiresValue: true,
        valueFieldName: "title"
      )
    }

    app.post("api", "v1", "spaces", ":spaceID", "cards", ":cardID", "actions", "url") { req async throws -> HTTPStatus in
      let spaceID = try spaceID(from: req)
      return try await handleActionRoute(
        req: req,
        center: center,
        spaceID: spaceID,
        mappedAction: "set-url",
        requiresValue: true,
        valueFieldName: "url"
      )
    }

    app.post("api", "v1", "spaces", ":spaceID", "cards", ":cardID", "actions", "directory") { req async throws -> HTTPStatus in
      let spaceID = try spaceID(from: req)
      return try await handleActionRoute(
        req: req,
        center: center,
        spaceID: spaceID,
        mappedAction: "set-directory",
        requiresValue: true,
        valueFieldName: "directory"
      )
    }

  }
}

public final class CardHubVaporService {
  public let center: CardCommandCenter
  public let app: Application

  public init(
    environment: Environment = .development,
    hostname: String = "127.0.0.1",
    port: Int = 28080,
    center: CardCommandCenter = CardCommandCenter()
  ) throws {
    self.center = center
    app = Application(environment)
    app.http.server.configuration.hostname = hostname
    app.http.server.configuration.port = port
    try CardHubVapor.configure(app, center: center)
  }

  public func start() throws {
    try app.start()
  }

  public func stop() {
    app.shutdown()
  }
}
