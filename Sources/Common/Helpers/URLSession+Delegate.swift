import ComposableArchitecture
import Foundation

// MARK: - DownloadTaskContainer

public struct DownloadTaskContainer: @unchecked Sendable {
  public weak var task: URLSessionDownloadTask?
  public let onProgressUpdate: @Sendable (Double) -> Void
  public let onComplete: @Sendable (Result<URL, Error>) -> Void

  public init(
    task: URLSessionDownloadTask?,
    onProgressUpdate: @escaping @Sendable (Double) -> Void,
    onComplete: @escaping @Sendable (Result<URL, Error>) -> Void
  ) {
    self.task = task
    self.onProgressUpdate = onProgressUpdate
    self.onComplete = onComplete
  }
}

// MARK: - UploadTaskContainer

public struct UploadTaskContainer: @unchecked Sendable {
  public weak var task: URLSessionUploadTask?
  public let onProgressUpdate: @Sendable (Double) -> Void
  public let onComplete: @Sendable (Result<Void, Error>) -> Void

  public init(
    task: URLSessionUploadTask?,
    onProgressUpdate: @escaping @Sendable (Double) -> Void,
    onComplete: @escaping @Sendable (Result<Void, Error>) -> Void
  ) {
    self.task = task
    self.onProgressUpdate = onProgressUpdate
    self.onComplete = onComplete
  }
}

// MARK: - SessionDelegate

public final class SessionDelegate: NSObject, URLSessionDownloadDelegate {
  private let downloadTasks = LockIsolated<[DownloadTaskContainer]>([])
  private let uploadTasks = LockIsolated<[UploadTaskContainer]>([])

  public func addDownloadTask(
    _ task: URLSessionDownloadTask,
    onProgressUpdate: @escaping @Sendable (Double) -> Void,
    onComplete: @escaping @Sendable (Result<URL, Error>) -> Void
  ) {
    downloadTasks.withValue {
      $0.append(DownloadTaskContainer(task: task, onProgressUpdate: onProgressUpdate, onComplete: onComplete))
    }
  }

  public func addUploadTask(
    _ task: URLSessionUploadTask,
    onProgressUpdate: @escaping @Sendable (Double) -> Void,
    onComplete: @escaping @Sendable (Result<Void, Error>) -> Void
  ) {
    uploadTasks.withValue {
      $0.append(UploadTaskContainer(task: task, onProgressUpdate: onProgressUpdate, onComplete: onComplete))
    }
  }

  public func urlSession(_: URLSession, downloadTask: URLSessionDownloadTask, didFinishDownloadingTo location: URL) {
    for taskContainer in downloadTasks.value where taskContainer.task == downloadTask {
      taskContainer.onComplete(.success(location))
    }
  }

  public func urlSession(
    _: URLSession,
    downloadTask: URLSessionDownloadTask,
    didWriteData _: Int64,
    totalBytesWritten: Int64,
    totalBytesExpectedToWrite: Int64
  ) {
    for taskContainer in downloadTasks.value where taskContainer.task == downloadTask {
      let progress = Double(totalBytesWritten) / Double(totalBytesExpectedToWrite)
      taskContainer.onProgressUpdate(progress)
    }
  }

  public func urlSession(_: URLSession, task: URLSessionTask, didCompleteWithError error: Error?) {
    if let error {
      for taskContainer in downloadTasks.value where taskContainer.task == task {
        taskContainer.onComplete(.failure(error))
      }
      for taskContainer in uploadTasks.value where taskContainer.task == task {
        taskContainer.onComplete(.failure(error))
      }
    } else {
      for taskContainer in uploadTasks.value where taskContainer.task == task {
        taskContainer.onComplete(.success(()))
      }
    }
  }

  public func urlSession(
    _: URLSession,
    task: URLSessionTask,
    didSendBodyData _: Int64,
    totalBytesSent: Int64,
    totalBytesExpectedToSend: Int64
  ) {
    for taskContainer in uploadTasks.value where taskContainer.task == task {
      let progress = Double(totalBytesSent) / Double(totalBytesExpectedToSend)
      taskContainer.onProgressUpdate(progress)
    }
  }
}
