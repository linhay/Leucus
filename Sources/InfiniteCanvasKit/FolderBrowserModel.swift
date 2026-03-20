import Foundation
import STFilePath

public enum FolderBrowserEntryKind: String, Sendable, Equatable {
  case folder
  case file
  case other
}

public struct FolderBrowserEntry: Sendable, Equatable, Identifiable {
  public let path: String
  public let name: String
  public let kind: FolderBrowserEntryKind

  public var id: String { path }
}

public enum FolderBrowserModel {
  public static func resolvedDirectoryPath(preferred: String?) -> String {
    if let preferred, !preferred.isEmpty {
      let anyPath = STPath(preferred)
      if let folder = anyPath.asFolder, folder.isFolderExists {
        return folder.url.path
      }
      if let file = anyPath.asFile, let parent = file.parentFolder(), parent.isFolderExists {
        return parent.url.path
      }
    }
    return STFolder.Sanbox.home.url.path
  }

  public static func parentPath(of path: String) -> String? {
    let folder = STFolder(resolvedDirectoryPath(preferred: path))
    guard let parent = folder.parentFolder() else { return nil }
    let parentPath = parent.url.path
    guard parentPath != folder.url.path else { return nil }
    return parentPath
  }

  public static func directoryTitle(for path: String) -> String {
    let folder = STFolder(resolvedDirectoryPath(preferred: path))
    let name = folder.attributes.name
    return name.isEmpty ? folder.url.path : name
  }

  public static func entries(at path: String, includeHidden: Bool = false) -> [FolderBrowserEntry] {
    let folder = STFolder(resolvedDirectoryPath(preferred: path))
    let predicates: [STFolder.SearchPredicate] = includeHidden ? [] : [.skipsHiddenFiles]
    guard let items = try? folder.subFilePaths(predicates) else {
      return []
    }

    return items
      .map { item in
        let resolvedName = item.attributes.name.isEmpty ? item.url.lastPathComponent : item.attributes.name
        return FolderBrowserEntry(
          path: item.url.path,
          name: resolvedName,
          kind: kind(for: item)
        )
      }
      .sorted {
        let lhsRank = sortRank($0.kind)
        let rhsRank = sortRank($1.kind)
        if lhsRank != rhsRank { return lhsRank < rhsRank }
        return $0.name.localizedStandardCompare($1.name) == .orderedAscending
      }
  }

  private static func kind(for path: STPath) -> FolderBrowserEntryKind {
    switch path.referenceType {
    case .folder: return .folder
    case .file: return .file
    case .none: return .other
    }
  }

  private static func sortRank(_ kind: FolderBrowserEntryKind) -> Int {
    switch kind {
    case .folder: return 0
    case .file: return 1
    case .other: return 2
    }
  }
}
