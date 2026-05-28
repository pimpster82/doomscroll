import XCTest
@testable import DoomScroll

final class OverrideTrackerTests: XCTestCase {

    private static let testSuite = "test.doomscroll.overrides"

    override func setUp() {
        super.setUp()
        // Wipe any state from a previous test and inject a fresh store.
        UserDefaults.standard.removePersistentDomain(forName: Self.testSuite)
        SharedDefaults.store = UserDefaults(suiteName: Self.testSuite) ?? .standard
    }

    override func tearDown() {
        UserDefaults.standard.removePersistentDomain(forName: Self.testSuite)
        super.tearDown()
    }

    // MARK: - Constants

    func testMaxOverridesPerDayIsTwo() {
        XCTAssertEqual(OverrideTracker.maxOverridesPerDay, 2)
    }

    // MARK: - canOverride

    func testCanOverrideWithNoneUsed() {
        XCTAssertTrue(OverrideTracker.canOverride(for: "app1"))
    }

    func testCanOverrideAfterOne() {
        OverrideTracker.recordOverride(for: "app1")
        XCTAssertTrue(OverrideTracker.canOverride(for: "app1"))
    }

    func testCannotOverrideAfterLimitReached() {
        OverrideTracker.recordOverride(for: "app1")
        OverrideTracker.recordOverride(for: "app1")
        XCTAssertFalse(OverrideTracker.canOverride(for: "app1"))
    }

    // MARK: - remainingToday

    func testRemainingCountsDownCorrectly() {
        XCTAssertEqual(OverrideTracker.remainingToday(for: "app1"), 2)
        OverrideTracker.recordOverride(for: "app1")
        XCTAssertEqual(OverrideTracker.remainingToday(for: "app1"), 1)
        OverrideTracker.recordOverride(for: "app1")
        XCTAssertEqual(OverrideTracker.remainingToday(for: "app1"), 0)
    }

    func testRemainingNeverGoesNegative() {
        OverrideTracker.recordOverride(for: "app1")
        OverrideTracker.recordOverride(for: "app1")
        OverrideTracker.recordOverride(for: "app1") // third call beyond limit
        XCTAssertEqual(OverrideTracker.remainingToday(for: "app1"), 0)
    }

    // MARK: - attemptOverride (atomic)

    func testAttemptOverrideSucceedsUnderLimit() {
        XCTAssertTrue(OverrideTracker.attemptOverride(for: "app1"))
        XCTAssertTrue(OverrideTracker.attemptOverride(for: "app1"))
    }

    func testAttemptOverrideFailsAtLimit() {
        _ = OverrideTracker.attemptOverride(for: "app1")
        _ = OverrideTracker.attemptOverride(for: "app1")
        XCTAssertFalse(OverrideTracker.attemptOverride(for: "app1"))
    }

    func testAttemptOverride_countedByOverridesToday() {
        _ = OverrideTracker.attemptOverride(for: "app1")
        XCTAssertEqual(OverrideTracker.overridesToday(for: "app1"), 1)
    }

    func testAttemptOverrideEnforcesLimitAfterRecordOverride() {
        OverrideTracker.recordOverride(for: "app1")   // non-atomic first
        XCTAssertTrue(OverrideTracker.attemptOverride(for: "app1"))  // atomic second — should succeed
        XCTAssertFalse(OverrideTracker.attemptOverride(for: "app1")) // third — should fail
    }

    // MARK: - Per-token isolation

    func testLimitIsPerToken() {
        OverrideTracker.recordOverride(for: "app1")
        OverrideTracker.recordOverride(for: "app1")
        // app2 is independent of app1's limit
        XCTAssertTrue(OverrideTracker.canOverride(for: "app2"))
        XCTAssertEqual(OverrideTracker.overridesToday(for: "app2"), 0)
    }

    // MARK: - totalOverridesToday

    func testTotalStartsAtZero() {
        XCTAssertEqual(OverrideTracker.totalOverridesToday(), 0)
    }

    func testTotalAggregatesAcrossTokens() {
        OverrideTracker.recordOverride(for: "app1")
        OverrideTracker.recordOverride(for: "app2")
        XCTAssertEqual(OverrideTracker.totalOverridesToday(), 2)
    }

    func testTotalWithMixedTokens() {
        OverrideTracker.recordOverride(for: "app1")
        OverrideTracker.recordOverride(for: "app1")
        OverrideTracker.recordOverride(for: "app2")
        XCTAssertEqual(OverrideTracker.totalOverridesToday(), 3)
    }

    // MARK: - Streak — initial state

    func testStreakStartsAtZero() {
        XCTAssertEqual(OverrideTracker.currentStreak(), 0)
    }

    func testBestStreakStartsAtZero() {
        XCTAssertEqual(OverrideTracker.bestStreak(), 0)
    }

    // MARK: - Streak — breaking

    func testStreakBreaksWhenAllOverridesExhausted() {
        SharedDefaults.store.set(5, forKey: SharedDefaults.Key.streakCount)
        OverrideTracker.recordOverride(for: "app1") // 1st override — no break yet
        OverrideTracker.recordOverride(for: "app1") // 2nd override — limit reached → break
        XCTAssertEqual(OverrideTracker.currentStreak(), 0)
    }

    func testStreakNotBrokenOnFirstOverrideAlone() {
        SharedDefaults.store.set(3, forKey: SharedDefaults.Key.streakCount)
        OverrideTracker.recordOverride(for: "app1") // only 1 of 2 used
        XCTAssertEqual(OverrideTracker.currentStreak(), 3)
    }

    func testAttemptOverrideBreaksStreakAtLimit() {
        SharedDefaults.store.set(5, forKey: SharedDefaults.Key.streakCount)
        _ = OverrideTracker.attemptOverride(for: "app1")
        _ = OverrideTracker.attemptOverride(for: "app1") // exhausts limit
        XCTAssertEqual(OverrideTracker.currentStreak(), 0)
    }

    // MARK: - Streak — advancing

    func testAdvanceStreak_incrementsWhenPreviousDayWasNotBroken() {
        seedYesterdayStreak(count: 3, broken: false)
        OverrideTracker.advanceStreakForNewDay()
        XCTAssertEqual(OverrideTracker.currentStreak(), 4)
    }

    func testAdvanceStreak_doesNotIncrementWhenPreviousDayWasBroken() {
        seedYesterdayStreak(count: 3, broken: true)
        OverrideTracker.advanceStreakForNewDay()
        XCTAssertEqual(OverrideTracker.currentStreak(), 3) // unchanged
    }

    func testAdvanceStreak_isIdempotentForSameDay() {
        seedYesterdayStreak(count: 2, broken: false)
        OverrideTracker.advanceStreakForNewDay()
        OverrideTracker.advanceStreakForNewDay() // second call same day — no-op
        XCTAssertEqual(OverrideTracker.currentStreak(), 3)
    }

    func testAdvanceStreak_updatesBestWhenNewStreakIsHigher() {
        SharedDefaults.store.set(10, forKey: SharedDefaults.Key.bestStreak)
        seedYesterdayStreak(count: 10, broken: false)
        OverrideTracker.advanceStreakForNewDay()
        XCTAssertEqual(OverrideTracker.bestStreak(), 11)
    }

    func testAdvanceStreak_doesNotLowerBestStreak() {
        SharedDefaults.store.set(20, forKey: SharedDefaults.Key.bestStreak)
        seedYesterdayStreak(count: 5, broken: false)
        OverrideTracker.advanceStreakForNewDay()
        XCTAssertEqual(OverrideTracker.bestStreak(), 20) // best preserved
    }

    // MARK: - Helpers

    private func seedYesterdayStreak(count: Int, broken: Bool) {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        SharedDefaults.store.set(f.string(from: yesterday), forKey: SharedDefaults.Key.lastStreakDate)
        SharedDefaults.store.set(broken, forKey: SharedDefaults.Key.streakBrokenToday)
        SharedDefaults.store.set(count, forKey: SharedDefaults.Key.streakCount)
    }
}
