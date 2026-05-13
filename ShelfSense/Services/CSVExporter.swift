import Foundation

struct CSVExporter {
    static func makeExportURL(receipts: [Receipt]) -> URL {
        let csv = buildCSV(receipts: receipts)
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ShelfSense_Export.csv")
        try? csv.write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    private static func buildCSV(receipts: [Receipt]) -> String {
        var rows = ["Date,Store,Item,Quantity,Price,Category"]
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"

        for receipt in receipts.sorted(by: { $0.date > $1.date }) {
            let date = formatter.string(from: receipt.date)
            let store = escape(receipt.storeName)
            for entry in receipt.items {
                let name = escape(entry.groceryItem?.name ?? "Unknown")
                let qty = String(format: "%.0f", entry.quantity)
                let price = String(format: "%.2f", entry.price)
                let category = escape(entry.groceryItem?.category ?? "")
                rows.append("\(date),\(store),\(name),\(qty),\(price),\(category)")
            }
        }
        return rows.joined(separator: "\n")
    }

    private static func escape(_ value: String) -> String {
        if value.contains(",") || value.contains("\"") || value.contains("\n") {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }
}
