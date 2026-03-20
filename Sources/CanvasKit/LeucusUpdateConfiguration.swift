import Foundation

public enum LeucusUpdateConfiguration {
  public static let feedURLInfoKey = "SUFeedURL"
  public static let publicKeyInfoKey = "SUPublicEDKey"

  public static func resolvedFeedURL(from infoDictionary: [String: Any]) -> URL? {
    normalizedFeedURL(from: infoDictionary[feedURLInfoKey] as? String)
  }

  public static func normalizedFeedURL(from value: String?) -> URL? {
    guard let value else { return nil }
    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
    guard
      !trimmed.isEmpty,
      let url = URL(string: trimmed),
      let scheme = url.scheme?.lowercased(),
      scheme == "http" || scheme == "https"
    else {
      return nil
    }
    return url
  }

  public static func hasPublicKey(in infoDictionary: [String: Any]) -> Bool {
    guard let value = infoDictionary[publicKeyInfoKey] as? String else { return false }
    return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
  }
}
