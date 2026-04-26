import ComposableArchitecture
import Foundation

public extension SharedReaderKey where Self == FileStorageKey<IdentifiedArrayOf<RecordingInfo>>.Default {
  static var recordings: Self {
    Self[.fileStorage(recordingsStorageURL), default: []]
  }
}

public extension SharedReaderKey where Self == InMemoryKey<IdentifiedArrayOf<TranscriptionTask>>.Default {
  static var transcriptionTasks: Self {
    Self[.inMemory(#function), default: []]
  }
}

public extension SharedReaderKey where Self == InMemoryKey<Bool>.Default {
  static var isICloudSyncInProgress: Self {
    Self[.inMemory(#function), default: false]
  }
}

public extension SharedReaderKey where Self == FileStorageKey<Settings> {
  static var settings: Self {
    .fileStorage(Configs.persistenceDirectoryURL.appendingPathComponent("settings.json"))
  }
}

private var recordingsStorageURL: URL {
  let destinationURL = Configs.persistenceDirectoryURL.appendingPathComponent("recordings.json")
  let legacyURL = URL.documentsDirectory.appendingPathComponent("recordings.json")
  let fileManager = FileManager.default

  guard !fileManager.fileExists(atPath: destinationURL.path),
        fileManager.fileExists(atPath: legacyURL.path)
  else { return destinationURL }

  do {
    let data = try Data(contentsOf: legacyURL)
    _ = try JSONDecoder().decode(IdentifiedArrayOf<RecordingInfo>.self, from: data)
    try fileManager.copyItem(at: legacyURL, to: destinationURL)
  } catch {
    let quarantineURL = URL.documentsDirectory
      .appendingPathComponent("recordings.corrupt.\(Int(Date().timeIntervalSince1970)).json")
    try? fileManager.moveItem(at: legacyURL, to: quarantineURL)
  }

  return destinationURL
}
