import SwiftUI
import SwiftData
import UserNotifications

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("monthly_budget")       private var monthlyBudget: Double = 0
    @AppStorage("debugModeUnlocked") private var debugModeUnlocked = false
    @AppStorage("showParseDebug") private var showParseDebug = false
    @State private var authStatus: UNAuthorizationStatus = .notDetermined
    @State private var versionTapCount = 0
    @State private var showUnlockedBanner = false
    @State private var debugToast: String? = nil
    @State private var budgetInput: String = ""
    @FocusState private var budgetFieldFocused: Bool
    @ObservedObject private var scanLimit = ScanLimitManager.shared
    @AppStorage(ScanMetrics.keyAttempts) private var metricsAttempts = 0
    @AppStorage(ScanMetrics.keyFailures) private var metricsFailures = 0
    @AppStorage(ScanMetrics.keyApiCalls) private var metricsApiCalls = 0

    @Query private var allReceipts: [Receipt]

    var body: some View {
        NavigationStack {
            List {
                notificationsSection
                budgetSection
                aiScanningSection
                dataSummarySection
                aboutSection
                if debugModeUnlocked {
                    debugSection
                }
            }
            .greenNavTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                        .foregroundStyle(.white)
                }
            }
            .overlay(alignment: .top) {
                if showUnlockedBanner {
                    Text("🛠 Developer mode unlocked")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Theme.primary)
                        .clipShape(Capsule())
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.3), value: showUnlockedBanner)
            .overlay(alignment: .bottom) {
                if let msg = debugToast {
                    Text(msg)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(Color.orange)
                        .clipShape(Capsule())
                        .padding(.bottom, 24)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .animation(.easeInOut(duration: 0.25), value: debugToast)
        }
        .task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            authStatus = settings.authorizationStatus
        }
    }

    // MARK: - Budget Section

    private var budgetSection: some View {
        Section {
            HStack {
                Label {
                    Text("Monthly Budget")
                } icon: {
                    Image(systemName: "dollarsign.circle.fill")
                        .foregroundStyle(Theme.mint)
                }
                Spacer()
                TextField("e.g. $400", text: $budgetInput)
                    .multilineTextAlignment(.trailing)
                    .keyboardType(.decimalPad)
                    .frame(maxWidth: 120)
                    .foregroundStyle(Color(.label))
                    .focused($budgetFieldFocused)
                    .onChange(of: budgetFieldFocused) { _, isFocused in
                        if isFocused {
                            // Clear on focus so the user types a fresh value
                            budgetInput = ""
                        } else {
                            // Parse on blur: strip currency symbols/commas
                            let cleaned = budgetInput
                                .replacingOccurrences(of: "$", with: "")
                                .replacingOccurrences(of: ",", with: "")
                                .trimmingCharacters(in: .whitespaces)
                            if let value = Double(cleaned), value > 0 {
                                monthlyBudget = value
                            } else if cleaned.isEmpty {
                                monthlyBudget = 0
                            }
                            // Show formatted value when not editing
                            budgetInput = monthlyBudget > 0
                                ? monthlyBudget.formatted(.currency(code: "USD"))
                                : ""
                        }
                    }
                    .onAppear {
                        budgetInput = monthlyBudget > 0
                            ? monthlyBudget.formatted(.currency(code: "USD"))
                            : ""
                    }
            }

            if monthlyBudget > 0 {
                Button(role: .destructive) {
                    monthlyBudget = 0
                    budgetInput = ""
                } label: {
                    Text("Remove Budget")
                }
            }
        } header: {
            Text("Monthly Budget")
        } footer: {
            Text("Set a monthly grocery spending goal to track progress on your dashboard. Leave empty to disable.")
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

    // MARK: - AI Scanning Section

    private var aiScanningSection: some View {
        Section {
            HStack {
                Text("AI scans used")
                Spacer()
                Text("\(scanLimit.scansUsed) / \(ScanLimitManager.freeLimit)")
                    .foregroundStyle(.secondary)
            }

            ProgressView(value: scanLimit.progressValue)
                .tint(scanLimit.hasAIScansRemaining ? Theme.mint : .orange)

            Text("Resets on the 1st of each month")
                .font(.caption)
                .foregroundStyle(.secondary)
        } header: {
            Text("AI Scanning")
        } footer: {
            Text("AI scanning sends your receipt text to a secure server for processing. Your Claude API key is never stored in the app.")
        }
    }

    // MARK: - Data Section

    @State private var showDeleteAllConfirmation = false

    private var dataSummarySection: some View {
        Section {
            Button(role: .destructive) {
                showDeleteAllConfirmation = true
            } label: {
                Label("Delete All Receipt Data", systemImage: "trash")
            }
            .confirmationDialog(
                "Delete all \(allReceipts.count) receipts and stores?",
                isPresented: $showDeleteAllConfirmation,
                titleVisibility: .visible
            ) {
                Button("Delete Everything", role: .destructive) {
                    allReceipts.forEach { modelContext.delete($0) }
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This permanently removes all receipts, stores, and price history. It cannot be undone.")
            }
        } header: {
            Text("Data")
        } footer: {
            Text("\(allReceipts.count) receipt\(allReceipts.count == 1 ? "" : "s") in database.")
        }
    }

    // MARK: - About Section

    private var aboutSection: some View {
        Section("About") {
            // Tapping version 5 times unlocks debug mode
            Button {
                versionTapCount += 1
                if versionTapCount >= 5 {
                    versionTapCount = 0
                    guard !debugModeUnlocked else { return }
                    debugModeUnlocked = true
                    showUnlockedBanner = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.5) {
                        showUnlockedBanner = false
                    }
                }
            } label: {
                LabeledContent("Version", value: appVersion)
                    .foregroundStyle(Color(.label))
            }
            .buttonStyle(.plain)

            LabeledContent("Build", value: buildNumber)
        }
    }

    // MARK: - Debug Section (hidden until unlocked)

    private var debugSection: some View {
        Group {
            Section {
                LabeledContent("Total Scans Attempted", value: "\(metricsAttempts)")
                LabeledContent("Validation Failures", value: "\(metricsFailures)")
                LabeledContent("API Calls Made", value: "\(metricsApiCalls)")
                LabeledContent("API Calls Saved", value: "\(ScanMetrics.apiCallsSaved)")
                    .foregroundStyle(metricsFailures > 0 ? Theme.mint : .secondary)
            } header: {
                Text("Cost Savings")
            } footer: {
                Text("API calls saved: \(ScanMetrics.apiCallsSaved) of \(metricsAttempts) scan attempts caught by pre-validation.")
            }

            Section {
                Toggle(isOn: $showParseDebug) {
                    Label {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Show Parse Debug Info")
                                .font(.body)
                            Text("After each scan, show OCR output and parse decisions")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "ant.fill")
                            .foregroundStyle(.orange)
                    }
                }
                .tint(.orange)

                Button(role: .destructive) {
                    debugModeUnlocked = false
                    showParseDebug = false
                } label: {
                    Label("Hide Debug Section", systemImage: "eye.slash")
                        .font(.subheadline)
                }
            } header: {
                Text("Developer")
            } footer: {
                Text("Debug mode shows raw Vision OCR output and explains why each line was accepted or rejected.")
            }

            #if DEBUG
            Section {
                Button {
                    ScanLimitManager.shared.setScansForDebug(ScanLimitManager.freeLimit)
                    flashToast("Scan limit set to \(ScanLimitManager.freeLimit)/\(ScanLimitManager.freeLimit)")
                } label: {
                    Label("Simulate \(ScanLimitManager.freeLimit) Scans Used", systemImage: "arrow.up.circle")
                        .font(.subheadline)
                }
                .foregroundStyle(.orange)

                Button {
                    ScanLimitManager.shared.setScansForDebug(0)
                    flashToast("Scan count reset to 0")
                } label: {
                    Label("Reset Scan Count to 0", systemImage: "arrow.counterclockwise.circle")
                        .font(.subheadline)
                }
                .foregroundStyle(.orange)
            } header: {
                Text("Scan Limit Testing")
            }
            #endif
        }
    }

    private func flashToast(_ message: String) {
        debugToast = message
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) { debugToast = nil }
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
