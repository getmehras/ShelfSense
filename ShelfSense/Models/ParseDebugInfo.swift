import Foundation

struct ParseDebugInfo {

    struct RejectedLine: Identifiable {
        let id = UUID()
        let text: String
        let reason: String
    }

    struct AcceptedItem: Identifiable {
        let id = UUID()
        let originalLine: String
        let cleanedName: String
        let price: Double
    }

    let rawLines: [String]
    let storeName: String
    let detectedTotal: Double?
    let acceptedItems: [AcceptedItem]
    let rejectedLines: [RejectedLine]

    var rawText: String { rawLines.joined(separator: "\n") }
    var itemCount: Int { acceptedItems.count }
    var rejectedCount: Int { rejectedLines.count }
}
