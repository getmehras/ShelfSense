import XCTest
@testable import ShelfSense

// SubscriptionManager is now a free-only stub (isPro always false).
// These tests verify ScanLimitManager behaves correctly without any Pro bypass.
final class SubscriptionTests: XCTestCase {

    private var defaults: UserDefaults!
    private var sut: ScanLimitManager!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "test.subscription.\(UUID().uuidString)")!
        sut = ScanLimitManager(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: defaults.volatileDomainNames.first ?? "")
        sut = nil
        defaults = nil
        super.tearDown()
    }

    func testLimitEnforcedAfterFreeScansUsed() {
        for _ in 0..<ScanLimitManager.freeLimit { sut.useAIScan() }
        XCTAssertFalse(sut.hasAIScansRemaining)
    }

    func testProgressIsNonZeroAfterUse() {
        sut.useAIScan()
        XCTAssertGreaterThan(sut.progressValue, 0.0)
    }

    func testProgressReachesOneWhenFullyUsed() {
        for _ in 0..<ScanLimitManager.freeLimit { sut.useAIScan() }
        XCTAssertEqual(sut.progressValue, 1.0, accuracy: 0.001)
    }

    func testStatusTextNeverMentionsUpgradeOrPro() {
        for _ in 0..<ScanLimitManager.freeLimit { sut.useAIScan() }
        let text = sut.statusText.lowercased()
        XCTAssertFalse(text.contains("upgrade"))
        XCTAssertFalse(text.contains("pro"))
    }
}
