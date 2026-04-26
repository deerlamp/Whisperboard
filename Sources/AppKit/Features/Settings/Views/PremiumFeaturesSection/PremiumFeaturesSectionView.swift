import CasePaths
import Common
import ComposableArchitecture
import Inject
import StoreKit
import SwiftUI

// MARK: - PremiumFeaturesSection

@Reducer
struct PremiumFeaturesSection: Sendable {
  @ObservableState
  struct State: Equatable, Sendable {
    @Shared(.premiumFeatures) var premiumFeatures
    @Presents var purchaseModal: PurchaseLiveTranscriptionModal.State?
  }

  @CasePathable
  enum Action: BindableAction, Sendable {
    case binding(BindingAction<State>)
    case buyLiveTranscriptionTapped
    case purchaseModal(PresentationAction<PurchaseLiveTranscriptionModal.Action>)
    case onTask
    case checkPurchaseStatus(Bool)
    case productFound(Bool)
  }

  var body: some ReducerOf<Self> {
    BindingReducer()
    Reduce<State, Action> { state, action in
      switch action {
      case .buyLiveTranscriptionTapped:
        state.purchaseModal = PurchaseLiveTranscriptionModal.State()
        return .none

      case .purchaseModal(.presented(.delegate(.didFinishTransaction))):
        state.purchaseModal = nil
        state.$premiumFeatures.withLock {
          $0.liveTranscriptionIsPurchased = true
        }
        return .none

      case .binding, .purchaseModal:
        return .none

      case .onTask:
        return .run { send in
          let products = try await Product.products(for: [PremiumFeaturesProductID.liveTranscription])
          let product = products.first
          await send(.productFound(product != nil))

          // Check initial purchase status
          let isPurchased = await product?.currentEntitlement != nil
          await send(.checkPurchaseStatus(isPurchased))

          // Subscribe to transaction updates
          for await result in Transaction.updates {
            if case let .verified(transaction) = result {
              if transaction.productID == PremiumFeaturesProductID.liveTranscription {
                let isPurchased = transaction.revocationDate == nil
                await send(.checkPurchaseStatus(isPurchased))
                await transaction.finish()
              }
            }
          }
        }

      case let .checkPurchaseStatus(isPurchased):
        state.$premiumFeatures.withLock {
          $0.liveTranscriptionIsPurchased = isPurchased
        }
        return .none

      case let .productFound(isFound):
        state.$premiumFeatures.withLock {
          $0.isProductFound = isFound
        }
        return .none
      }
    }
    .ifLet(\.$purchaseModal, action: \.purchaseModal) {
      PurchaseLiveTranscriptionModal()
    }
  }
}

// MARK: - PremiumFeaturesSectionView

@MainActor
struct PremiumFeaturesSectionView: View {
  @Perception.Bindable var store: StoreOf<PremiumFeaturesSection>

  @ObserveInjection var injection

  var body: some View {
    WithPerceptionTracking {
      Section("Premium Features") {
        SettingsButton(
          icon: .system(name: "waveform", background: Color.DS.Background.accent),
          title: "Live Transcription",
          trailingText: store.premiumFeatures.liveTranscriptionIsPurchased ?? false ? "Purchased" : "Not Purchased",
          indicator: store.premiumFeatures.liveTranscriptionIsPurchased ?? false ? nil : .chevron
        ) {
          if !(store.premiumFeatures.liveTranscriptionIsPurchased ?? false) {
            store.send(.buyLiveTranscriptionTapped)
          }
        }
      }
      .sheet(
        item: $store.scope(state: \.purchaseModal, action: \.purchaseModal)
      ) { store in
        PurchaseLiveTranscriptionModalView(store: store)
      }
      .listRowBackground(Color.DS.Background.secondary)
      .listRowSeparator(.hidden)
      .enableInjection()
    }
  }
}
