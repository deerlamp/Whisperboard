import ComposableArchitecture

// MARK: - DebugSettings

public struct DebugSettings: Codable, Hashable, Sendable {
  public var shouldOverridePurchaseStatus = false
  public var liveTranscriptionIsPurchasedOverride = false
}

public extension SharedReaderKey where Self == FileStorageKey<DebugSettings>.Default {
  static var debugSettings: Self {
    Self[.fileStorage(.documentsDirectory.appending(component: "debugSettings.json")), default: DebugSettings()]
  }
}
