import UserNotifications
import Foundation

final class NotificationService {
    static let shared = NotificationService()
    private init() {}

    private let center = UNUserNotificationCenter.current()

    var isEnabled: Bool {
        UserDefaults.standard.object(forKey: "notificationsEnabled") as? Bool ?? true
    }

    func requestPermissionIfNeeded() {
        Task {
            let current = await center.notificationSettings()
            guard current.authorizationStatus == .notDetermined else { return }
            try? await center.requestAuthorization(options: [.alert, .sound, .badge])
        }
    }

    struct PriceIncrease {
        let itemName: String
        let changePct: Int
    }

    // Returns true when a price increase meets the alert threshold (>= 10%)
    static func shouldTriggerAlert(oldPrice: Double, newPrice: Double) -> Bool {
        guard oldPrice > 0 else { return false }
        return newPrice >= oldPrice * 1.10
    }

    static func buildTitle(count: Int, storeName: String) -> String {
        count == 1
            ? "1 item costs more at \(storeName)"
            : "\(count) items cost more at \(storeName)"
    }

    static func buildBody(increases: [PriceIncrease]) -> String {
        let count = increases.count
        let shown = increases.prefix(3).map { "\($0.itemName) +\($0.changePct)%" }
        return count > 3
            ? shown.joined(separator: ", ") + " and \(count - 3) more"
            : shown.joined(separator: ", ")
    }

    // Groups all price increases from one receipt save into a single notification.
    // Identifier is per-store so a repeat scan replaces the previous alert.
    func scheduleGroupedPriceAlert(increases: [PriceIncrease], storeName: String) {
        guard isEnabled, !increases.isEmpty else { return }

        let title = NotificationService.buildTitle(count: increases.count, storeName: storeName)
        let body  = NotificationService.buildBody(increases: increases)

        let content = UNMutableNotificationContent()
        content.title = title
        content.body  = body
        content.sound = .default

        let id = "price-alert-" + storeName.lowercased()
            .components(separatedBy: .alphanumerics.inverted)
            .filter { !$0.isEmpty }
            .joined(separator: "-")

        // 2-second delay so the notification arrives after the app backgrounds
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }
}
