import Combine

// App is free — subscription removed. Stub retained so call sites compile without changes.
@MainActor
class SubscriptionManager: ObservableObject {
    static let shared = SubscriptionManager()
    @Published var isPro: Bool = false
}
