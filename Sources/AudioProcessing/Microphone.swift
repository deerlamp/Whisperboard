import AVFoundation

// MARK: - Microphone

public struct Microphone: Hashable, Equatable, Identifiable, Sendable {
  public let id: String
  public let isBuiltIn: Bool
  public let portName: String

  #if os(iOS)
    public init(_ port: AVAudioSessionPortDescription) {
      self.id = port.uid
      self.isBuiltIn = port.portType == .builtInMic
      self.portName = port.portName
    }
  #else
    public init() {
      self.id = "0"
      self.isBuiltIn = false
      self.portName = ""
    }
  #endif
}

public extension Microphone {
  func hash(into hasher: inout Hasher) {
    hasher.combine(id)
  }

  static func == (lhs: Microphone, rhs: Microphone) -> Bool {
    lhs.id == rhs.id
  }
}
