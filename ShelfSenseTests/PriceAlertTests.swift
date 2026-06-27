import XCTest
@testable import ShelfSense

final class PriceAlertTests: XCTestCase {

    // MARK: - shouldTriggerAlert

    func testExactlyTenPercentTriggers() {
        // 1.10 * 100 = 110 — at the threshold, should fire
        XCTAssertTrue(NotificationService.shouldTriggerAlert(oldPrice: 1.00, newPrice: 1.10))
    }

    func testJustBelowTenPercentDoesNotTrigger() {
        XCTAssertFalse(NotificationService.shouldTriggerAlert(oldPrice: 1.00, newPrice: 1.099))
    }

    func testAboveTenPercentTriggers() {
        XCTAssertTrue(NotificationService.shouldTriggerAlert(oldPrice: 2.00, newPrice: 2.50))
    }

    func testPriceDropDoesNotTrigger() {
        XCTAssertFalse(NotificationService.shouldTriggerAlert(oldPrice: 3.00, newPrice: 2.00))
    }

    func testZeroOldPriceDoesNotTrigger() {
        XCTAssertFalse(NotificationService.shouldTriggerAlert(oldPrice: 0, newPrice: 5.00))
    }

    func testNegativeOldPriceDoesNotTrigger() {
        XCTAssertFalse(NotificationService.shouldTriggerAlert(oldPrice: -1.0, newPrice: 2.00))
    }

    // MARK: - buildTitle

    func testTitleSingularForOneItem() {
        let title = NotificationService.buildTitle(count: 1, storeName: "Walmart")
        XCTAssertEqual(title, "1 item costs more at Walmart")
    }

    func testTitlePluralForMultipleItems() {
        let title = NotificationService.buildTitle(count: 3, storeName: "Costco")
        XCTAssertEqual(title, "3 items cost more at Costco")
    }

    // MARK: - buildBody

    func testBodyListsAllWhenThreeOrFewer() {
        let increases = [
            NotificationService.PriceIncrease(itemName: "Milk", changePct: 12),
            NotificationService.PriceIncrease(itemName: "Eggs", changePct: 15),
        ]
        let body = NotificationService.buildBody(increases: increases)
        XCTAssertTrue(body.contains("Milk +12%"))
        XCTAssertTrue(body.contains("Eggs +15%"))
        XCTAssertFalse(body.contains("more"))
    }

    func testBodyShowsOverflowWhenMoreThanThree() {
        let increases = (1...5).map {
            NotificationService.PriceIncrease(itemName: "Item\($0)", changePct: 10)
        }
        let body = NotificationService.buildBody(increases: increases)
        XCTAssertTrue(body.contains("and 2 more"))
        // Only first 3 named items appear
        XCTAssertTrue(body.contains("Item1"))
        XCTAssertTrue(body.contains("Item3"))
        XCTAssertFalse(body.contains("Item4"))
    }

    func testBodyExactlyFourShowsAndOnMore() {
        let increases = (1...4).map {
            NotificationService.PriceIncrease(itemName: "P\($0)", changePct: 20)
        }
        let body = NotificationService.buildBody(increases: increases)
        XCTAssertTrue(body.contains("and 1 more"))
    }
}
