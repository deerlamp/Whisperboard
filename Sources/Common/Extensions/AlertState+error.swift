import ComposableArchitecture

public extension AlertState {
  static func error(_ error: Error) -> Self {
    Self(
      title: { TextState("Something went wrong") },
      message: { TextState(error.localizedDescription) }
    )
  }

  static func error(message: String) -> Self {
    Self(
      title: { TextState("Something went wrong") },
      message: { TextState(message) }
    )
  }

  static var genericError: Self {
    Self(
      title: { TextState("Something went wrong") },
      message: { TextState("Please try again later.") }
    )
  }
}
