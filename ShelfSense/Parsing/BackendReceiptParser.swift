import Foundation

struct BackendReceiptParser {

    struct Result {
        let items: [ParsedReceiptItem]
        let storeName: String
        let storeAddress: String?
        let purchaseDate: Date?
        let receiptSubtotal: Double?
        let salesTax: Double?
        let receiptTotal: Double?
    }

    static func parse(
        rawOCRText: String,
        storeName: String = ""
    ) async throws -> Result {

        guard let url = URL(string: SupabaseConfig.parseReceiptURL) else {
            throw ParserError.invalidURL
        }

        let body: [String: Any] = [
            "ocrText": stripSensitiveData(rawOCRText),
            "storeName": storeName
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json",    forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(SupabaseConfig.anonKey)", forHTTPHeaderField: "Authorization")
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let http = response as? HTTPURLResponse else {
            throw ParserError.networkError
        }

        switch http.statusCode {
        case 200:       return try parseResponse(data)
        case 429:       throw ParserError.rateLimited
        case 500, 502:  throw ParserError.serverError
        default:        throw ParserError.networkError
        }
    }

    static func parseResponse(_ data: Data) throws -> Result {
        guard
            let json  = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let array = json["items"] as? [[String: Any]]
        else { throw ParserError.invalidResponse }

        let backendStoreName    = StoreNameNormalizer.normalize(json["storeName"] as? String ?? "")
        let backendStoreAddress = json["storeAddress"]   as? String
        let backendSubtotal     = json["receiptSubtotal"] as? Double
        let backendSalesTax     = json["salesTax"]        as? Double
        let backendReceiptTotal = json["receiptTotal"]    as? Double

        let backendPurchaseDate: Date? = {
            guard let dateString = json["purchaseDate"] as? String else { return nil }
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            return formatter.date(from: dateString)
        }()

        let items: [ParsedReceiptItem] = array.compactMap { item in
            guard
                let name  = item["name"]  as? String, name.count >= 2,
                let price = item["price"] as? Double, price >= 0.25, price <= 500,
                !isPaymentLine(name)
            else { return nil }
            let qty         = (item["quantity"]    as? Double) ?? Double(item["quantity"] as? Int ?? 1)
            let category    = item["category"]    as? String
            let subCategory = item["subCategory"] as? String
            return ParsedReceiptItem(name: name, price: price, quantity: qty,
                                     category: category, subCategory: subCategory)
        }

        return Result(items: items, storeName: backendStoreName,
                      storeAddress: backendStoreAddress, purchaseDate: backendPurchaseDate,
                      receiptSubtotal: backendSubtotal, salesTax: backendSalesTax,
                      receiptTotal: backendReceiptTotal)
    }

    private static func stripSensitiveData(_ text: String) -> String {
        var cleaned = text

        // Masked card numbers: ****1234, XXXX 1234
        cleaned = cleaned.replacingOccurrences(
            of: #"[X\*]{4,}[\s]?\d{4}"#,
            with: "", options: .regularExpression)

        // Approval / auth codes
        cleaned = cleaned.replacingOccurrences(
            of: #"(?i)(appr|approval|auth)[\s#:]+\w+"#,
            with: "", options: .regularExpression)

        // AID numbers
        cleaned = cleaned.replacingOccurrences(
            of: #"AID\s*:\s*[A-F0-9]+"#,
            with: "", options: .regularExpression)

        // Transaction / ref / seq IDs
        cleaned = cleaned.replacingOccurrences(
            of: #"(?i)(tran|ref|seq)[\s#:]+\w+"#,
            with: "", options: .regularExpression)

        // Phone numbers
        cleaned = cleaned.replacingOccurrences(
            of: #"\(?\d{3}\)?[\s.-]\d{3}[\s.-]\d{4}"#,
            with: "", options: .regularExpression)

        // IVR / TSR / ARC codes
        cleaned = cleaned.replacingOccurrences(
            of: #"(IVK|TSR|ARC)\s*:\s*\w+"#,
            with: "", options: .regularExpression)

        return cleaned
    }

    private static func isPaymentLine(_ name: String) -> Bool {
        let upper = name.uppercased()
        let cardKeywords = [
            "VISA", "MASTERCARD", "MASTER CARD", "AMEX", "AMERICAN EXPRESS",
            "DISCOVER", "INTERAC", "CREDIT CARD", "DEBIT CARD",
            "CARD ENDING", "CARD NUMBER", "LAST 4", "LAST FOUR",
            "PAYMENT", "APPROVED", "AUTHORIZATION",
        ]
        if cardKeywords.contains(where: { upper.contains($0) }) { return true }
        // Masked card number: ****1234, XXXX 1234
        if upper.range(of: #"[*X]{2,}[\s\-]*\d{3,4}"#, options: .regularExpression) != nil { return true }
        return false
    }

    enum ParserError: Error, LocalizedError {
        case invalidURL
        case networkError
        case rateLimited
        case serverError
        case invalidResponse

        var errorDescription: String? {
            switch self {
            case .invalidURL:        return "Invalid server URL"
            case .networkError:      return "No internet connection"
            case .rateLimited:       return "Too many requests — please wait a moment"
            case .serverError:       return "Server error — please try again"
            case .invalidResponse:   return "Unexpected server response"
            }
        }
    }
}
