import ComposableArchitecture
import Dependencies
import SwiftUI
import XCTestDynamicOverlay

extension DependencyValues {
  var openSettings: @Sendable ()
    async -> Void {
    get { self[OpenSettingsKey.self] }
    set { self[OpenSettingsKey.self] = newValue }
  }

  private enum OpenSettingsKey: DependencyKey {
    typealias Value = @Sendable () async -> Void

    static let liveValue: @Sendable () async -> Void = {
      guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
      await MainActor.run {
        UIApplication.shared.open(url)
      }
    }

    static let testValue: @Sendable () async -> Void = unimplemented(
      #"@Dependency(\.openSettings)"#
    )
  }
}
