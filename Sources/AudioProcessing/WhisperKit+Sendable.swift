@preconcurrency import WhisperKit

extension AudioProcessor: @unchecked @retroactive Sendable {}
extension TranscriptionProgress: @unchecked @retroactive Sendable {}
extension TranscriptionResult: @unchecked @retroactive Sendable {}
extension TranscriptionSegment: @unchecked @retroactive Sendable {}
extension TranscriptionTimings: @unchecked @retroactive Sendable {}
extension WordTiming: @unchecked @retroactive Sendable {}
