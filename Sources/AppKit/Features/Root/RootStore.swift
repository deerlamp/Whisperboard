@preconcurrency import BackgroundTasks
import Combine
import Common
import ComposableArchitecture
import SwiftUI

// MARK: - Root

@Reducer
struct Root: Sendable {
  @Reducer
  @CasePathable
  enum Path {
    case list
    case settings
    case details(RecordingDetails)
  }

  @ObservableState
  struct State: Sendable {
    var transcriptionWorker = TranscriptionWorker.State()
    var recordingListScreen = RecordingListScreen.State()
    var recordScreen = RecordScreen.State()
    var settingsScreen = SettingsScreen.State()
    var path = StackState<Path.State>()
    var isGoToNewRecordingPopupPresented = false

    @Presents var alert: AlertState<Action.Alert>?

    var isRecording: Bool {
      recordScreen.recordingControls.recording != nil
    }

    var isTranscribing: Bool {
      transcriptionWorker.isProcessing
    }

    var shouldDisableIdleTimer: Bool {
      isRecording || isTranscribing
    }
  }

  @CasePathable
  enum Action: BindableAction, Sendable {
    case task
    case binding(BindingAction<State>)
    case transcriptionWorker(TranscriptionWorker.Action)
    case recordingListScreen(RecordingListScreen.Action)
    case recordScreen(RecordScreen.Action)
    case settingsScreen(SettingsScreen.Action)
    case path(StackActionOf<Path>)
    case alert(PresentationAction<Alert>)
    case didCompleteICloudSync(TaskResult<Void>)
    case registerForBGProcessingTasks(TranscriptionWorker.BGProcessingTaskWrapper)
    case goToNewRecordingButtonTapped
    case recordingListButtonTapped
    case settingsButtonTapped

    enum Alert: Equatable {}
  }

  @Dependency(StorageClient.self) var storage: StorageClient
  @Dependency(\.keychainClient) var keychainClient: KeychainClient
  @Dependency(\.subscriptionClient) var subscriptionClient: SubscriptionClient
  @Dependency(\.application) var application: Application

  var body: some Reducer<State, Action> {
    BindingReducer()
      .onChange(of: \.shouldDisableIdleTimer) { _, shouldDisableIdleTimer in
        Reduce<State, Action> { _, _ in
          .run { _ in
            await MainActor.run { application.isIdleTimerDisabled = shouldDisableIdleTimer }
          }
        }
      }
      .onChange(of: \.recordScreen.recordingControls.recording?.recordingInfo.fileURL) { _, url in
        Reduce<State, Action> { _, _ in
          storage.setCurrentRecordingURL(url: url)
          return .none
        }
      }

    Scope(state: \.transcriptionWorker, action: \.transcriptionWorker) {
      TranscriptionWorker()
    }

    Scope(state: \.recordingListScreen, action: \.recordingListScreen) {
      RecordingListScreen()
    }

    Scope(state: \.recordScreen, action: \.recordScreen) {
      RecordScreen()
    }

    Scope(state: \.settingsScreen, action: \.settingsScreen) {
      SettingsScreen()
    }

    Reduce<State, Action> { state, action in
      switch action {
      case .task:
        // Pausing unfinished transcription on app launch
        for recording in state.recordingListScreen.recordings {
          if let transcription = recording.transcription, transcription.status.isLoadingOrProgress {
            logs.debug("Marking \(recording.fileName) transcription as failed")
            state.recordingListScreen.$recordings.withLock {
              $0[id: recording.id]?.transcription?.status = .error(message: "Transcription failed, please try again.")
            }
            state.transcriptionWorker.$taskQueue.withLock {
              $0[id: transcription.id] = nil
            }
          }
        }

        return .run { _ in
          subscriptionClient.configure(keychainClient.userID)
        }

      case .recordingListScreen(.didFinishImportingFiles),
           .settingsScreen(.setICloudSyncEnabled(true)):
        return .run { send in
          await send(.didCompleteICloudSync(TaskResult { try await uploadNewRecordingsToICloudIfNeeded() }))
        }

      case let .recordingListScreen(.delegate(.recordingCardTapped(cardState))):
        state.path.append(.details(RecordingDetails.State(recordingCard: cardState)))
        return .none

      // Inserts a new recording into the recording list and enqueues a transcription task if auto-transcription is enabled
      case let .recordScreen(.delegate(.newRecordingCreated(recordingInfo))):
        _ = state.recordingListScreen.$recordings.withLock {
          $0.insert(recordingInfo, at: 0)
        }
        state.isGoToNewRecordingPopupPresented = true

        return .run { send in
          await send(.didCompleteICloudSync(TaskResult { try await uploadNewRecordingsToICloudIfNeeded() }))
        }

      case .path(.element(_, .details(.delegate(.deleteDialogConfirmed)))):
        guard let id = state.path.last?.details?.recordingCard.id else { return .none }
        state.recordingListScreen.$recordings.withLock {
          $0.removeAll(where: { $0.id == id })
        }
        state.path.removeLast()
        return .none

      case .settingsScreen(.alert(.presented(.deleteStorageDialogConfirmed))):
        state.path.removeAll()
        return .none

      case .didCompleteICloudSync(.success):
        return .none

      case let .didCompleteICloudSync(.failure(error)):
        logs.error("Failed to sync with iCloud: \(error)")
        state.alert = .init(
          title: { .init("Failed to sync with iCloud") },
          actions: {
            ButtonState {
              .init("OK")
            }
          },
          message: { .init(error.localizedDescription) }
        )
        return .none

      case let .registerForBGProcessingTasks(wrapper):
        return .run { send in
          await send(.transcriptionWorker(.handleBGProcessingTask(wrapper)))
        }

      case let .path(.element(_, .details(.recordingCard(.delegate(.enqueueTaskForRecordingID(recordingID)))))),
           let .recordingListScreen(.recordingCard(.element(_, .delegate(.enqueueTaskForRecordingID(recordingID))))):
        return .run { [state] send in
          await send(.transcriptionWorker(.enqueueTaskForRecordingID(recordingID, state.settingsScreen.settings)))
        }

      case let .path(.element(_, .details(.recordingCard(.delegate(.cancelTaskForRecordingID(recordingID)))))),
           let .recordingListScreen(.recordingCard(.element(_, .delegate(.cancelTaskForRecordingID(recordingID))))):
        return .run { send in
          await send(.transcriptionWorker(.cancelTaskForRecordingID(recordingID)))
        }

      case let .path(.element(_, .details(.recordingCard(.delegate(.resumeTask(task)))))),
           let .recordingListScreen(.recordingCard(.element(_, .delegate(.resumeTask(task))))):
        return .run { send in
          await send(.transcriptionWorker(.resumeTask(task)))
        }

      case .goToNewRecordingButtonTapped:
        if let recordingCard = state.recordingListScreen.recordingCards.first {
          state.path.append(.details(RecordingDetails.State(recordingCard: recordingCard)))
        }
        return .none

      case .recordingListButtonTapped:
        state.path.append(.list)
        return .none

      case .settingsButtonTapped:
        state.path.append(.settings)
        return .none

      default:
        return .none
      }
    }
    .ifLet(\.$alert, action: \.alert)
    .forEach(\.path, action: \.path)
  }

  func uploadNewRecordingsToICloudIfNeeded() async throws {
    @Shared(.settings) var settings: Settings
    @Shared(.recordings) var recordings: IdentifiedArrayOf<RecordingInfo>
    @Shared(.isICloudSyncInProgress) var isICloudSyncInProgress: Bool

    if settings.isICloudSyncEnabled {
      $isICloudSyncInProgress.withLock { $0 = true }
      defer { $isICloudSyncInProgress.withLock { $0 = false } }
      try await storage.uploadRecordingsToICloud(reset: false, recordings: recordings.elements)
    }
  }
}

// MARK: - Root.Path.State + Equatable, Sendable

extension Root.Path.State: Equatable, Sendable {}

// MARK: - Root.Path.Action + Sendable

extension Root.Path.Action: Sendable {}
