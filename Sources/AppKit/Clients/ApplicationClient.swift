@preconcurrency import CasePaths
@preconcurrency import ComposableArchitecture
@preconcurrency import Dependencies
import UIKit

struct Application: Sendable {
  var getIsIdleTimerDisabled: @Sendable @MainActor () -> Bool
  var setIsIdleTimerDisabled: @Sendable @MainActor (Bool) -> Void

  @MainActor
  var isIdleTimerDisabled: Bool {
    get { getIsIdleTimerDisabled() }
    nonmutating set { setIsIdleTimerDisabled(newValue) }
  }
}

extension Application: DependencyKey {
  static let liveValue = Application(
    getIsIdleTimerDisabled: { UIApplication.shared.isIdleTimerDisabled },
    setIsIdleTimerDisabled: { UIApplication.shared.isIdleTimerDisabled = $0 }
  )

  static let testValue = Application(
    getIsIdleTimerDisabled: { false },
    setIsIdleTimerDisabled: { _ in }
  )
}

extension DependencyValues {
  var application: Application {
    get { self[Application.self] }
    set { self[Application.self] = newValue }
  }
}
