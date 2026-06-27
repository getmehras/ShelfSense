import Foundation
import Combine

class ScanLimitManager: ObservableObject {

    static let shared = ScanLimitManager()
    static let freeLimit = 20

    @Published var scansUsed: Int = 0
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        resetIfNewMonth()
        scansUsed = defaults.integer(forKey: "ai_scans_used")
    }

    private func resetIfNewMonth() {
        let currentMonth = Calendar.current.component(.month, from: Date())
        let savedMonth   = defaults.integer(forKey: "ai_scan_month")
        if savedMonth != currentMonth {
            defaults.set(0, forKey: "ai_scans_used")
            defaults.set(currentMonth, forKey: "ai_scan_month")
            scansUsed = 0
        }
    }

    // Force a month rollover for testing the reset logic
    func simulateNewMonth() {
        let nextMonth = (Calendar.current.component(.month, from: Date()) % 12) + 1
        defaults.set(nextMonth, forKey: "ai_scan_month")
        resetIfNewMonth()
        scansUsed = defaults.integer(forKey: "ai_scans_used")
    }

    var hasAIScansRemaining: Bool {
        scansUsed < ScanLimitManager.freeLimit
    }

    var scansRemaining: Int { max(0, ScanLimitManager.freeLimit - scansUsed) }

    var progressValue: Double {
        min(1.0, Double(scansUsed) / Double(ScanLimitManager.freeLimit))
    }

    func useAIScan() {
        scansUsed += 1
        defaults.set(scansUsed, forKey: "ai_scans_used")
    }

    #if DEBUG
    func setScansForDebug(_ count: Int) {
        scansUsed = count
        defaults.set(count, forKey: "ai_scans_used")
    }
    #endif

    var statusText: String {
        if hasAIScansRemaining {
            return "\(scansRemaining) AI scans remaining this month"
        }
        return "AI scans used up — resets \(nextResetDate)"
    }

    var nextResetDate: String {
        var components = Calendar.current.dateComponents([.year, .month], from: Date())
        components.month! += 1
        components.day = 1
        let firstOfNextMonth = Calendar.current.date(from: components) ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"
        return formatter.string(from: firstOfNextMonth)
    }

    var usageText: String {
        "\(scansUsed) of \(ScanLimitManager.freeLimit) free AI scans used this month"
    }
}
