import Foundation
import Testing
import Vapor
import XCTVapor
@testable import CardHubService

struct CardHubServiceTests {
  @Test
  func postAndDrainCommandsShouldWork() throws {
    let app = Application(.testing)
    defer { app.shutdown() }
    let center = CardCommandCenter()
    try CardHubVapor.configure(app, center: center)

    let spaceID = UUID()
    let targetID = UUID()
    let sourceID = UUID()
    let payload = CardControlCommandRequest(
      sourceCardID: sourceID,
      targetCardID: targetID,
      action: "set-title",
      value: "FromHub",
      metadata: nil
    )

    try XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
      try app.test(.POST, "api/v1/spaces/\(spaceID.uuidString)/commands", beforeRequest: { req in
        try req.content.encode(payload)
      }, afterResponse: { response in
        #expect(response.status == .accepted)
      })

      try app.test(.GET, "api/v1/spaces/\(spaceID.uuidString)/cards/\(targetID.uuidString)/commands", afterResponse: { response in
        #expect(response.status == .ok)
        let commands = try response.content.decode([CardControlCommand].self)
        #expect(commands.count == 1)
        #expect(commands[0].spaceID == spaceID)
        #expect(commands[0].targetCardID == targetID)
        #expect(commands[0].sourceCardID == sourceID)
        #expect(commands[0].action == "set-title")
        #expect(commands[0].value == "FromHub")
      })

      try app.test(.GET, "api/v1/spaces/\(spaceID.uuidString)/cards/\(targetID.uuidString)/commands", afterResponse: { response in
        #expect(response.status == .ok)
        let commands = try response.content.decode([CardControlCommand].self)
        #expect(commands.isEmpty)
      })
    }
  }

  @Test
  func postCommandShouldRejectEmptyAction() throws {
    let app = Application(.testing)
    defer { app.shutdown() }
    try CardHubVapor.configure(app, center: CardCommandCenter())

    let payload = CardControlCommandRequest(
      sourceCardID: nil,
      targetCardID: UUID(),
      action: "   ",
      value: nil,
      metadata: nil
    )

    try XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
      try app.test(.POST, "api/v1/spaces/\(UUID().uuidString)/commands", beforeRequest: { req in
        try req.content.encode(payload)
      }, afterResponse: { response in
        #expect(response.status == .badRequest)
      })
    }
  }

  @Test
  func commandsShouldBeIsolatedBySpace() throws {
    let app = Application(.testing)
    defer { app.shutdown() }
    try CardHubVapor.configure(app, center: CardCommandCenter())

    let cardID = UUID()
    let spaceA = UUID()
    let spaceB = UUID()

    let payloadA = CardControlCommandRequest(
      sourceCardID: nil,
      targetCardID: cardID,
      action: "set-title",
      value: "A",
      metadata: nil
    )
    let payloadB = CardControlCommandRequest(
      sourceCardID: nil,
      targetCardID: cardID,
      action: "set-title",
      value: "B",
      metadata: nil
    )

    try XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
      try app.test(.POST, "api/v1/spaces/\(spaceA.uuidString)/commands", beforeRequest: { req in
        try req.content.encode(payloadA)
      }, afterResponse: { response in
        #expect(response.status == .accepted)
      })

      try app.test(.POST, "api/v1/spaces/\(spaceB.uuidString)/commands", beforeRequest: { req in
        try req.content.encode(payloadB)
      }, afterResponse: { response in
        #expect(response.status == .accepted)
      })

      try app.test(.GET, "api/v1/spaces/\(spaceA.uuidString)/cards/\(cardID.uuidString)/commands", afterResponse: { response in
        #expect(response.status == .ok)
        let commands = try response.content.decode([CardControlCommand].self)
        #expect(commands.map(\.value) == ["A"])
      })

      try app.test(.GET, "api/v1/spaces/\(spaceB.uuidString)/cards/\(cardID.uuidString)/commands", afterResponse: { response in
        #expect(response.status == .ok)
        let commands = try response.content.decode([CardControlCommand].self)
        #expect(commands.map(\.value) == ["B"])
      })
    }
  }

  @Test
  func cardScopedRoutesShouldEnqueueMappedActions() throws {
    let app = Application(.testing)
    defer { app.shutdown() }
    try CardHubVapor.configure(app, center: CardCommandCenter())

    let spaceID = UUID()
    let cardID = UUID()
    let sourceID = UUID()

    try XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
      try app.test(.POST, "api/v1/spaces/\(spaceID.uuidString)/cards/\(cardID.uuidString)/actions/select", beforeRequest: { req in
        try req.content.encode(CardControlRouteRequest(sourceCardID: sourceID, metadata: nil))
      }, afterResponse: { response in
        #expect(response.status == .accepted)
      })

      try app.test(.POST, "api/v1/spaces/\(spaceID.uuidString)/cards/\(cardID.uuidString)/actions/title", beforeRequest: { req in
        try req.content.encode(CardControlRouteValueRequest(sourceCardID: nil, value: "RouteTitle", metadata: nil))
      }, afterResponse: { response in
        #expect(response.status == .accepted)
      })

      try app.test(.POST, "api/v1/spaces/\(spaceID.uuidString)/cards/\(cardID.uuidString)/actions/url", beforeRequest: { req in
        try req.content.encode(CardControlRouteValueRequest(sourceCardID: nil, value: "https://example.com", metadata: nil))
      }, afterResponse: { response in
        #expect(response.status == .accepted)
      })

      try app.test(.POST, "api/v1/spaces/\(spaceID.uuidString)/cards/\(cardID.uuidString)/actions/directory", beforeRequest: { req in
        try req.content.encode(CardControlRouteValueRequest(sourceCardID: nil, value: "/tmp", metadata: nil))
      }, afterResponse: { response in
        #expect(response.status == .accepted)
      })

      try app.test(.POST, "api/v1/spaces/\(spaceID.uuidString)/cards/\(cardID.uuidString)/actions/close", afterResponse: { response in
        #expect(response.status == .accepted)
      })

      try app.test(.GET, "api/v1/spaces/\(spaceID.uuidString)/cards/\(cardID.uuidString)/commands", afterResponse: { response in
        #expect(response.status == .ok)
        let commands = try response.content.decode([CardControlCommand].self)
        #expect(commands.map(\.action) == ["select", "set-title", "set-url", "set-directory", "close"])
        #expect(commands.allSatisfy { $0.spaceID == spaceID })
        #expect(commands[0].sourceCardID == sourceID)
      })
    }
  }

  @Test
  func cardScopedValueRouteShouldRejectEmptyValue() throws {
    let app = Application(.testing)
    defer { app.shutdown() }
    try CardHubVapor.configure(app, center: CardCommandCenter())

    let cardID = UUID()
    try XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
      try app.test(.POST, "api/v1/spaces/\(UUID().uuidString)/cards/\(cardID.uuidString)/actions/title", beforeRequest: { req in
        try req.content.encode(CardControlRouteValueRequest(sourceCardID: nil, value: "   ", metadata: nil))
      }, afterResponse: { response in
        #expect(response.status == .badRequest)
      })
    }
  }

  @Test
  func cardRouteDiscoveryShouldReturnDescriptors() throws {
    let app = Application(.testing)
    defer { app.shutdown() }
    try CardHubVapor.configure(app, center: CardCommandCenter())

    let spaceID = UUID()
    let cardID = UUID()
    try XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
      try app.test(.GET, "api/v1/spaces/\(spaceID.uuidString)/cards/\(cardID.uuidString)/routes", afterResponse: { response in
        #expect(response.status == .ok)
        let body = try response.content.decode(CardRouteDiscoveryResponse.self)
        #expect(body.spaceID == spaceID)
        #expect(body.cardID == cardID)
        #expect(body.routes.count == 5)
        #expect(body.routes.map(\.action) == ["select", "close", "title", "url", "directory"])
        #expect(body.routes.first?.method == "POST")
        #expect(body.routes.first?.pathTemplate == "/api/v1/spaces/:spaceID/cards/:cardID/actions/select")
      })
    }
  }

  @Test
  func cardRouteDiscoveryShouldRejectInvalidCardID() throws {
    let app = Application(.testing)
    defer { app.shutdown() }
    try CardHubVapor.configure(app, center: CardCommandCenter())

    try XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
      try app.test(.GET, "api/v1/spaces/not-a-uuid/cards/not-a-uuid/routes", afterResponse: { response in
        #expect(response.status == .badRequest)
      })
    }
  }

  @Test
  func legacyRoutesShouldBeUnavailable() throws {
    let app = Application(.testing)
    defer { app.shutdown() }
    try CardHubVapor.configure(app, center: CardCommandCenter())

    try XCTVaporContext.$emitWarningIfCurrentTestInfoIsAvailable.withValue(false) {
      try app.test(.POST, "api/commands", afterResponse: { response in
        #expect(response.status == .notFound)
      })

      try app.test(.GET, "api/v1/canvases/\(UUID().uuidString)/cards/\(UUID().uuidString)/commands", afterResponse: { response in
        #expect(response.status == .notFound)
      })

      try app.test(.POST, "api/cards/\(UUID().uuidString)/select", afterResponse: { response in
        #expect(response.status == .notFound)
      })
    }
  }
}
