import XCTest
@testable import ShelfSense

final class ScanLimitManagerTests: XCTestCase {

    private var sut: ScanLimitManager!
    private var defaults: UserDefaults!

    override func setUp() {
        super.setUp()
        defaults = UserDefaults(suiteName: "test.scanlimit.\(UUID().uuidString)")!
        sut = ScanLimitManager(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: defaults.volatileDomainNames.first ?? "")
        sut = nil
        defaults = nil
        super.tearDown()
    }

    // MARK: - Initial state

    func testInitialScansUsedIsZero() {
        XCTAssertEqual(sut.scansUsed, 0)
    }

    func testInitialHasScansRemaining() {
        XCTAssertTrue(sut.hasAIScansRemaining)
    }

    // MARK: - useAIScan

    func testUseAIScanIncrementsCount() {
        sut.useAIScan()
        XCTAssertEqual(sut.scansUsed, 1)
    }

    func testUseAIScanPersistsToDefaults() {
        sut.useAIScan()
        sut.useAIScan()
        let stored = defaults.integer(forKey: "ai_scans_used")
        XCTAssertEqual(stored, 2)
    }

    func testScansRemainingDecreasesAfterUse() {
        sut.useAIScan()
        XCTAssertEqual(sut.scansRemaining, ScanLimitManager.freeLimit - 1)
    }

    // MARK: - Boundary: last scan

    func testLastScanStillHasRemaining() {
        for _ in 0..<(ScanLimitManager.freeLimit - 1) { sut.useAIScan() }
        XCTAssertTrue(sut.hasAIScansRemaining)
    }

    func testExactlyAtLimitHasNoRemaining() {
        for _ in 0..<ScanLimitManager.freeLimit { sut.useAIScan() }
        XCTAssertFalse(sut.hasAIScansRemaining)
    }

    func testScansRemainingNeverGoesNegative() {
        for _ in 0..<(ScanLimitManager.freeLimit + 5) { sut.useAIScan() }
        XCTAssertEqual(sut.scansRemaining, 0)
    }

    // MARK: - progressValue

    func testProgressValueZeroWhenEmpty() {
        XCTAssertEqual(sut.progressValue, 0.0, accuracy: 0.001)
    }

    func testProgressValueOneWhenFull() {
        for _ in 0..<ScanLimitManager.freeLimit { sut.useAIScan() }
        XCTAssertEqual(sut.progressValue, 1.0, accuracy: 0.001)
    }

    func testProgressValueHalfway() {
        let half = ScanLimitManager.freeLimit / 2
        for _ in 0..<half { sut.useAIScan() }
        let expected = Double(half) / Double(ScanLimitManager.freeLimit)
        XCTAssertEqual(sut.progressValue, expected, accuracy: 0.001)
    }

    // MARK: - simulateNewMonth

    func testSimulateNewMonthResetsScansUsed() {
        for _ in 0..<ScanLimitManager.freeLimit { sut.useAIScan() }
        XCTAssertFalse(sut.hasAIScansRemaining)
        sut.simulateNewMonth()
        XCTAssertEqual(sut.scansUsed, 0)
        XCTAssertTrue(sut.hasAIScansRemaining)
    }

    func testSimulateNewMonthResetsPersistence() {
        for _ in 0..<5 { sut.useAIScan() }
        sut.simulateNewMonth()
        XCTAssertEqual(defaults.integer(forKey: "ai_scans_used"), 0)
    }

    // MARK: - statusText

    func testStatusTextShowsRemainingWhenScansLeft() {
        XCTAssertTrue(sut.statusText.contains("remaining") || sut.statusText.contains("AI scans"))
    }

    func testStatusTextShowsExhaustedWhenEmpty() {
        for _ in 0..<ScanLimitManager.freeLimit { sut.useAIScan() }
        let text = sut.statusText.lowercased()
        XCTAssertTrue(text.contains("used up") || text.contains("resets"))
    }
}
