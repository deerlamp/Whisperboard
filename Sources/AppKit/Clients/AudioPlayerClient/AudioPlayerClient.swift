@preconcurrency import AudioProcessing
import Common
import ComposableArchitecture
import Dependencies
import Foundation

@preconcurrency import AVFoundation

// MARK: - AudioPlayerClient

struct AudioPlayerClient {
  var play: @Sendable (URL) -> AsyncStream<PlaybackState>
  var seekProgress: @Sendable (Double) async -> Void
  var pause: @Sendable () async -> Void
  var resume: @Sendable () async -> Void
  var stop: @Sendable () async -> Void
  var speed: @Sendable (Float) async -> Void
}

// MARK: DependencyKey

extension AudioPlayerClient: DependencyKey {
  final class Context: Sendable {
    fileprivate let audioPlayer = LockIsolated<AudioPlayer?>(nil)
    let continuation = LockIsolated<AsyncStream<PlaybackState>.Continuation?>(nil)

    init() {}
  }

  static let liveValue: AudioPlayerClient = {
    let context = Context()

    return AudioPlayerClient(
      play: { url in
        @Dependency(AudioSessionClient.self) var audioSession: AudioSessionClient

        if let audioPlayer = context.audioPlayer.value, audioPlayer.player.isPlaying {
          audioPlayer.player.stop()
          context.continuation.value?.yield(.stop)
        }

        return AsyncStream<PlaybackState> { continuation in
          do {
            context.continuation.setValue(continuation)
            let audioPlayer = try AudioPlayer(
              url: url,
              didFinishPlaying: { successful in
                try? audioSession.disable(.playback, true)
                continuation.yield(.finish(successful: successful))
                continuation.finish()
              },
              decodeErrorDidOccur: { error in
                try? audioSession.disable(.playback, true)
                continuation.yield(.error(error?.equatable))
                continuation.finish()
              }
            )
            context.audioPlayer.setValue(audioPlayer)

            try audioSession.enable(.playback, true)
            audioPlayer.player.play()
            let timerTask = Task {
              let clock = ContinuousClock()
              let lastPosition = PlaybackPosition(currentTime: 0, duration: 0)
              for await _ in clock.timer(interval: .seconds(0.5)) {
                let position = PlaybackPosition(
                  currentTime: audioPlayer.player.currentTime,
                  duration: audioPlayer.player.duration
                )
                guard lastPosition != position else { continue }
                if audioPlayer.player.isPlaying == true {
                  continuation.yield(.playing(position))
                } else {
                  continuation.yield(.pause(position))
                }
              }
            }
            continuation.onTermination = { _ in
              audioPlayer.player.stop()
              timerTask.cancel()
            }
          } catch {
            context.audioPlayer.value?.player.stop()
            continuation.yield(.error(error.equatable))
            continuation.finish()
          }
        }
      },
      seekProgress: { progress in
        if let player = context.audioPlayer.value?.player {
          let time = player.duration * progress
          player.currentTime = time
//          context.continuation?.yield(.playing(PlaybackPosition(
//            currentTime: context.audioPlayer?.player.currentTime ?? 0,
//            duration: context.audioPlayer?.player.duration ?? 0
//          )))
        }
      },
      pause: {
        context.audioPlayer.value?.player.pause()
//        context.continuation?.yield(.pause(PlaybackPosition(
//          currentTime: context.audioPlayer?.player.currentTime ?? 0,
//          duration: context.audioPlayer?.player.duration ?? 0
//        )))
      },
      resume: {
        context.audioPlayer.value?.player.play()
//        context.continuation?.yield(.playing(PlaybackPosition(
//          currentTime: context.audioPlayer?.player.currentTime ?? 0,
//          duration: context.audioPlayer?.player.duration ?? 0
//        )))
      },
      stop: {
        context.audioPlayer.value?.player.stop()
        context.continuation.value?.yield(.stop)
      },
      speed: { speed in
        context.audioPlayer.value?.player.rate = speed
      }
    )
  }()
}

extension DependencyValues {
  var audioPlayer: AudioPlayerClient {
    get { self[AudioPlayerClient.self] }
    set { self[AudioPlayerClient.self] = newValue }
  }
}

// MARK: - AudioPlayer

private final class AudioPlayer: NSObject, AVAudioPlayerDelegate, Sendable {
  let didFinishPlaying: @Sendable (Bool) -> Void
  let decodeErrorDidOccur: @Sendable (Error?) -> Void
  let player: AVAudioPlayer

  init(
    url: URL,
    didFinishPlaying: @escaping @Sendable (Bool) -> Void,
    decodeErrorDidOccur: @escaping @Sendable (Error?) -> Void
  ) throws {
    self.didFinishPlaying = didFinishPlaying
    self.decodeErrorDidOccur = decodeErrorDidOccur
    player = try AVAudioPlayer(contentsOf: url)
    super.init()
    player.delegate = self
  }

  func audioPlayerDidFinishPlaying(_: AVAudioPlayer, successfully flag: Bool) {
    didFinishPlaying(flag)
  }

  func audioPlayerDecodeErrorDidOccur(_: AVAudioPlayer, error: Error?) {
    decodeErrorDidOccur(error)
  }
}
