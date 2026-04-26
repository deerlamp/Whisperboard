import Foundation

// MARK: - TranscriptionTask

public struct TranscriptionTask: Identifiable, Codable, Hashable, Sendable, Then {
  public var id: UUID
  public var recordingInfoID: RecordingInfo.ID
  public var settings: Settings

  public init(
    id: UUID = UUID(),
    recordingInfoID: RecordingInfo.ID,
    settings: Settings
  ) {
    self.id = id
    self.recordingInfoID = recordingInfoID
    self.settings = settings
  }
}
