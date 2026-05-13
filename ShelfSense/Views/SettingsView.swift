import SwiftUI
import UserNotifications

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    // Same key as NotificationService.isEnabled so they stay in sync.
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @State private var authStatus: UNAuthorizationStatus = .notDetermined

    var body: some View {
        NavigationStack {
            List {
                notificationsSection
                aboutSection
            }
            .greenNavTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                }
            }
        }
        .task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            authStatus = settings.authorizationStatus
        }
    }

    // MARK: - Notifications Section

    private var notificationsSection: some View {
        Section {
            Toggle(isOn: $notificationsEnabled) {
                Label {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Price Alert Notifications")
                            .font(.body)
                        Text("Notify when a price rises more than 10%")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                } icon: {
                    Image(systemName: "bell.badge.fill")
                        .foregroundStyle(Theme.primary)
                }
            }
            .tint(Theme.mint)

            if authStatus == .denied {
                HStack(spacing: 10) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(.orange)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Notifications blocked")
                            .font(.subheadline.weight(.medium))
                        Text("Allow notifications for ShelfSense in iOS Settings.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Button("Open iOS Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .foregroundStyle(Theme.primary)
            }
        } header: {
            Text("Notifications")
        } footer: {
            Text("Alerts are delivered locally — no account or server required.")
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: appVersion)
            LabeledContent("Build", value: buildNumber)
        }
    }

    private var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—"
    }

    private var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "—"
    }
}

#Preview {
    SettingsView()
}
