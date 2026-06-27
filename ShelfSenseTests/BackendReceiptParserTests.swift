import XCTest
@testable import ShelfSense

final class BackendReceiptParserTests: XCTestCase {

    // MARK: - Helpers

    private func json(_ dict: [String: Any]) throws -> Data {
        try JSONSerialization.data(withJSONObject: dict)
    }

    // MARK: - Happy path

    func testParsesBasicItemsCorrectly() throws {
        let data = try json([
            "items": [
                ["name": "Organic Milk", "price": 6.89, "quantity": 1],
                ["name": "Free Range Eggs", "price": 5.29, "quantity": 1],
            ],
            "storeName": "Whole Foods"
        ])
        let result = try BackendReceiptParser.parseResponse(data)
        XCTAssertEqual(result.items.count, 2)
        XCTAssertEqual(result.storeName, "Whole Foods")
    }

    func testItemNameAndPriceRoundTrip() throws {
        let data = try json([
            "items": [["name": "Baby Spinach", "price": 3.99, "quantity": 2]],
            "storeName": ""
        ])
        let result = try BackendReceiptParser.parseResponse(data)
        XCTAssertEqual(result.items.first?.name, "Baby Spinach")
        XCTAssertEqual(result.items.first?.price ?? 0, 3.99, accuracy: 0.001)
        XCTAssertEqual(result.items.first?.quantity ?? 0, 2.0, accuracy: 0.001)
    }

    func testStoreNameEmptyWhenMissingFromResponse() throws {
        let data = try json(["items": [["name": "Bread", "price": 2.99, "quantity": 1]]])
        let result = try BackendReceiptParser.parseResponse(data)
        XCTAssertEqual(result.storeName, "")
    }

    func testQuantityDefaultsToOneWhenMissing() throws {
        let data = try json([
            "items": [["name": "Butter", "price": 4.49]],
            "storeName": ""
        ])
        let result = try BackendReceiptParser.parseResponse(data)
        XCTAssertEqual(result.items.first?.quantity ?? 0, 1.0, accuracy: 0.001)
    }

    func testIntegerQuantityParsedCorrectly() throws {
        let data = try json([
            "items": [["name": "Yogurt", "price": 1.50, "quantity": 3]],
            "storeName": ""
        ])
        let result = try BackendReceiptParser.parseResponse(data)
        XCTAssertEqual(result.items.first?.quantity ?? 0, 3.0, accuracy: 0.001)
    }

    // MARK: - Filtering

    func testFiltersPriceBelowMinimum() throws {
        let data = try json([
            "items": [["name": "Gum", "price": 0.10, "quantity": 1]],
            "storeName": ""
        ])
        let result = try BackendReceiptParser.parseResponse(data)
        XCTAssertTrue(result.items.isEmpty)
    }

    func testFiltersPriceAboveMaximum() throws {
        let data = try json([
            "items": [["name": "Gold Bar", "price": 999.99, "quantity": 1]],
            "storeName": ""
        ])
        let result = try BackendReceiptParser.parseResponse(data)
        XCTAssertTrue(result.items.isEmpty)
    }

    func testFiltersItemWithNameTooShort() throws {
        let data = try json([
            "items": [["name": "X", "price": 2.99, "quantity": 1]],
            "storeName": ""
        ])
        let result = try BackendReceiptParser.parseResponse(data)
        XCTAssertTrue(result.items.isEmpty)
    }

    func testAcceptsItemAtMinimumPrice() throws {
        let data = try json([
            "items": [["name": "Salt", "price": 0.25, "quantity": 1]],
            "storeName": ""
        ])
        let result = try BackendReceiptParser.parseResponse(data)
        XCTAssertEqual(result.items.count, 1)
    }

    func testAcceptsItemAtMaximumPrice() throws {
        let data = try json([
            "items": [["name": "Wagyu Steak", "price": 500.0, "quantity": 1]],
            "storeName": ""
        ])
        let result = try BackendReceiptParser.parseResponse(data)
        XCTAssertEqual(result.items.count, 1)
    }

    // MARK: - Error cases

    func testThrowsOnInvalidJSON() {
        let data = "not json".data(using: .utf8)!
        XCTAssertThrowsError(try BackendReceiptParser.parseResponse(data))
    }

    func testThrowsWhenItemsKeyMissing() throws {
        let data = try json(["storeName": "Trader Joe's"])
        XCTAssertThrowsError(try BackendReceiptParser.parseResponse(data))
    }

    func testEmptyItemsArrayReturnsEmptyResult() throws {
        let data = try json(["items": [[String: Any]](), "storeName": ""])
        let result = try BackendReceiptParser.parseResponse(data)
        XCTAssertTrue(result.items.isEmpty)
    }
}
