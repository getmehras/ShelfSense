import UserNotifications
import Foundation

final class NotificationService {
    static let shared = NotificationService()
    private init() {}

    private let center = UNUserNotificationCenter.current()

    // Mirrors the @AppStorage("notificationsEnabled") key used in SettingsView.
    var isEnabled: Bool {
        UserDefaults.standard.object(forKey: "notificationsEnabled") as? Bool ?? true
    }

    // Asks for permission only when status is still undetermined (no-op otherwise).
    func requestPermissionIfNeeded() {
        Task {
            let current = await center.notificationSettings()
            guard current.authorizationStatus == .notDetermined else { return }
            try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        }
    }

    // Schedules a local notification when an item's price rises > 10%.
    // Uses the item name as the notification identifier so a repeat scan
    // replaces the previous alert for the same item rather than stacking.
    func schedulePriceAlert(
        itemName: String,
        storeName: String,
        oldPrice: Double,
        newPrice: Double
    ) {
        guard isEnabled else { return }
        guard oldPrice > 0, newPrice > oldPrice * 1.10 else { return }

        let changePct = Int(((newPrice - oldPrice) / oldPrice) * 100)
        let old = oldPrice.formatted(.currency(code: "USD"))
        let new = newPrice.formatted(.currency(code: "USD"))

        let content = UNMutableNotificationContent()
        content.title = "Price Alert — \(itemName)"
        content.body = "\(itemName) is up \(changePct)% at \(storeName). Was \(old), now \(new)."
        content.sound = .default

        let id = "price-alert-" + itemName.lowercased()
            .components(separatedBy: .alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")

        // 2-second delay so the notification arrives after the app backgrounds
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        let request = UNNotificationRequest(identifier: id, content: content, trigger: trigger)
        center.add(request)
    }
}
