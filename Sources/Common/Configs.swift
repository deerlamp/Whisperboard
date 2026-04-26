import Foundation

public enum Configs {
  public static var recordingsDirectoryURL: URL {
    .documentsDirectory
  }

  public static let persistenceDirectoryURL: URL = {
    let baseURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
      ?? .documentsDirectory
    let url = baseURL.appendingPathComponent("Whisperboard", isDirectory: true)
    do {
      try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    } catch {
      assertionFailure("Failed to create persistence directory at \(url.path): \(error)")
    }
    return url
  }()
}
