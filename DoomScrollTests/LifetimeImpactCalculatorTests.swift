import XCTest
@testable import DoomScroll

final class LifetimeImpactCalculatorTests: XCTestCase {

    private let currentYear = Calendar.current.component(.year, from: Date())

    // 35-year-old male, 82-year life expectancy → ~47 years remaining
    private var profile35Male: UserProfile {
        UserProfile(birthYear: currentYear - 35, gender: .male, lifeExpectancy: 82)
    }

    // MARK: - yearsAtCurrentRate

    func testYearsAtCurrentRateMatchesFormula() {
        let calc = LifetimeImpactCalculator(profile: profile35Male)
        let annualSeconds: TimeInterval = 3 * 3600 * 365  // 3 h/day
        let impact = calc.calculate(totalSecondsLastYear: annualSeconds)

        let expected = (annualSeconds / 365) * profile35Male.yearsRemaining * 365 / (365 * 24 * 3600)
        XCTAssertEqual(impact.yearsAtCurrentRate, expected, accuracy: 0.001)
    }

    func testYearsRecoverableIsHalfOfCurrentRate() {
        let calc = LifetimeImpactCalculator(profile: profile35Male)
        let impact = calc.calculate(totalSecondsLastYear: 3 * 3600 * 365)
        XCTAssertEqual(impact.yearsRecoverableAt50Percent, impact.yearsAtCurrentRate * 0.5, accuracy: 0.001)
    }

    func testDailyAverageIsAnnualDividedBy365() {
        let annualSeconds: TimeInterval = 3 * 3600 * 365
        let calc = LifetimeImpactCalculator(profile: profile35Male)
        let impact = calc.calculate(totalSecondsLastYear: annualSeconds)
        XCTAssertEqual(impact.dailyAverageSeconds, 3 * 3600, accuracy: 1)
    }

    // MARK: - Zero and boundary

    func testZeroUsageProducesZeroYears() {
        let calc = LifetimeImpactCalculator(profile: profile35Male)
        let impact = calc.calculate(totalSecondsLastYear: 0)
        XCTAssertEqual(impact.yearsAtCurrentRate, 0)
        XCTAssertEqual(impact.yearsRecoverableAt50Percent, 0)
        XCTAssertEqual(impact.dailyAverageSeconds, 0)
    }

    func testLargeUsageDoesNotCrash() {
        let calc = LifetimeImpactCalculator(profile: profile35Male)
        let impact = calc.calculate(totalSecondsLastYear: 16 * 3600 * 365) // 16 h/day
        XCTAssertGreaterThan(impact.yearsAtCurrentRate, 0)
    }

    // MARK: - relationalStake text

    func testRelationalStakeIsNonEmpty() {
        let calc = LifetimeImpactCalculator(profile: profile35Male)
        let impact = calc.calculate(totalSecondsLastYear: 3 * 3600 * 365)
        XCTAssertFalse(impact.relationalStake.isEmpty)
    }

    func testTeenRelationalStakeMentionsSleepOrTraining() {
        let teen = UserProfile(birthYear: currentYear - 16, gender: .female, lifeExpectancy: 82)
        let calc = LifetimeImpactCalculator(profile: teen)
        let impact = calc.calculate(totalSecondsLastYear: 3 * 3600 * 365)
        let stake = impact.relationalStake.lowercased()
        XCTAssertTrue(stake.contains("sleep") || stake.contains("train") || stake.contains("creat"),
                      "Expected teen stake to reference sleep/training/creating, got: \(impact.relationalStake)")
    }

    func testYoungAdultMaleStakeMentionsAlgorithmOrWeeks() {
        let ya = UserProfile(birthYear: currentYear - 28, gender: .male, lifeExpectancy: 82)
        let calc = LifetimeImpactCalculator(profile: ya)
        let impact = calc.calculate(totalSecondsLastYear: 3 * 3600 * 365)
        let stake = impact.relationalStake.lowercased()
        XCTAssertTrue(stake.contains("algorithm") || stake.contains("week"),
                      "Expected young adult male stake to reference algorithm/weeks, got: \(impact.relationalStake)")
    }

    func testYoungAdultFemaleStakeMentionsPartTime() {
        let ya = UserProfile(birthYear: currentYear - 28, gender: .female, lifeExpectancy: 82)
        let calc = LifetimeImpactCalculator(profile: ya)
        let impact = calc.calculate(totalSecondsLastYear: 3 * 3600 * 365)
        let stake = impact.relationalStake.lowercased()
        XCTAssertTrue(stake.contains("part") || stake.contains("content") || stake.contains("job"),
                      "Got: \(impact.relationalStake)")
    }

    // MARK: - appImpact

    func testAppImpactZeroTimeReturnsFirstTime() {
        let calc = LifetimeImpactCalculator(profile: profile35Male)
        let appImpact = calc.appImpact(appName: "Instagram", todaySeconds: 0, weeklyTotalSeconds: 0)
        XCTAssertEqual(appImpact.relationalStake, "First time today.")
    }

    func testAppImpactNonZeroIsNonEmpty() {
        let calc = LifetimeImpactCalculator(profile: profile35Male)
        let appImpact = calc.appImpact(appName: "TikTok", todaySeconds: 30 * 60, weeklyTotalSeconds: 5 * 3600)
        XCTAssertFalse(appImpact.relationalStake.isEmpty)
    }

    func testAppImpactContainsAppName() {
        let calc = LifetimeImpactCalculator(profile: profile35Male)
        let appImpact = calc.appImpact(appName: "Reddit", todaySeconds: 20 * 60, weeklyTotalSeconds: 3600)
        XCTAssertTrue(appImpact.relationalStake.contains("Reddit"))
    }

    func testAppImpactWeeklyAverageCalculation() {
        let calc = LifetimeImpactCalculator(profile: profile35Male)
        let weeklyTotal: TimeInterval = 7 * 3600  // 1 h/day
        let appImpact = calc.appImpact(appName: "App", todaySeconds: 3600, weeklyTotalSeconds: weeklyTotal)
        XCTAssertEqual(appImpact.weeklyAverageSeconds, 3600, accuracy: 1)
    }

    // MARK: - durationString helper

    func testDurationStringMinutesOnly() {
        XCTAssertEqual((45 * 60 as TimeInterval).durationString, "45m")
    }

    func testDurationStringHoursAndMinutes() {
        XCTAssertEqual((90 * 60 as TimeInterval).durationString, "1h 30m")
    }

    func testDurationStringZero() {
        XCTAssertEqual((0 as TimeInterval).durationString, "0m")
    }
}
