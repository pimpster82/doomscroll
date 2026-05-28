import XCTest
@testable import DoomScroll

final class ReflectionEngineTests: XCTestCase {

    private let currentYear = Calendar.current.component(.year, from: Date())
    private let app = "Instagram"

    // MARK: - All 9 age×gender combinations return valid prompts

    func testTeenFemale() {
        let p = UserProfile(birthYear: currentYear - 16, gender: .female)
        assertValid(ReflectionEngine.prompt(for: p, appName: app, todaySeconds: 600))
    }

    func testTeenMale() {
        let p = UserProfile(birthYear: currentYear - 16, gender: .male)
        assertValid(ReflectionEngine.prompt(for: p, appName: app, todaySeconds: 600))
    }

    func testTeenPreferNotToSay() {
        let p = UserProfile(birthYear: currentYear - 16, gender: .preferNotToSay)
        assertValid(ReflectionEngine.prompt(for: p, appName: app, todaySeconds: 600))
    }

    func testYoungAdultFemale() {
        let p = UserProfile(birthYear: currentYear - 25, gender: .female)
        assertValid(ReflectionEngine.prompt(for: p, appName: app, todaySeconds: 1800))
    }

    func testYoungAdultMale() {
        let p = UserProfile(birthYear: currentYear - 25, gender: .male)
        assertValid(ReflectionEngine.prompt(for: p, appName: app, todaySeconds: 1800))
    }

    func testYoungAdultPreferNotToSay() {
        let p = UserProfile(birthYear: currentYear - 25, gender: .preferNotToSay)
        assertValid(ReflectionEngine.prompt(for: p, appName: app, todaySeconds: 1800))
    }

    func testMidLifeFemale() {
        let p = UserProfile(birthYear: currentYear - 45, gender: .female)
        assertValid(ReflectionEngine.prompt(for: p, appName: app, todaySeconds: 0))
    }

    func testMidLifeMale() {
        let p = UserProfile(birthYear: currentYear - 45, gender: .male)
        assertValid(ReflectionEngine.prompt(for: p, appName: app, todaySeconds: 0))
    }

    func testMidLifePreferNotToSay() {
        let p = UserProfile(birthYear: currentYear - 45, gender: .preferNotToSay)
        assertValid(ReflectionEngine.prompt(for: p, appName: app, todaySeconds: 0))
    }

    // MARK: - App name injection

    func testTeenPromptContainsAppName() {
        let p = UserProfile(birthYear: currentYear - 16, gender: .male)
        let prompt = ReflectionEngine.prompt(for: p, appName: "TikTok", todaySeconds: 300)
        XCTAssertTrue(prompt.question.contains("TikTok"))
    }

    func testYoungAdultPromptContainsAppName() {
        let p = UserProfile(birthYear: currentYear - 28, gender: .female)
        let prompt = ReflectionEngine.prompt(for: p, appName: "Reddit", todaySeconds: 1200)
        XCTAssertTrue(prompt.question.contains("Reddit"))
    }

    // MARK: - Time injection (young adult prompts embed today's minutes)

    func testYoungAdultFemalePromptContainsTodayMinutes() {
        let p = UserProfile(birthYear: currentYear - 28, gender: .female)
        let prompt = ReflectionEngine.prompt(for: p, appName: app, todaySeconds: 30 * 60) // 30 min
        XCTAssertTrue(prompt.question.contains("30"))
    }

    func testYoungAdultMalePromptContainsTodayMinutes() {
        let p = UserProfile(birthYear: currentYear - 28, gender: .male)
        let prompt = ReflectionEngine.prompt(for: p, appName: app, todaySeconds: 45 * 60) // 45 min
        XCTAssertTrue(prompt.question.contains("45"))
    }

    func testZeroSecondsUsesFallbackOfOneMinute() {
        // ReflectionEngine uses max(1, Int(todaySeconds / 60)) so zero → "1 min"
        let p = UserProfile(birthYear: currentYear - 28, gender: .female)
        let prompt = ReflectionEngine.prompt(for: p, appName: app, todaySeconds: 0)
        XCTAssertTrue(prompt.question.contains("1"))
    }

    // MARK: - Tone expectations (spot-checks derived from research rationale)

    func testTeenMalePromptMentionsBeingHooked() {
        let p = UserProfile(birthYear: currentYear - 16, gender: .male)
        let prompt = ReflectionEngine.prompt(for: p, appName: app, todaySeconds: 300)
        // Teen male prompt should reference the algorithm's hook ("built to hook you")
        XCTAssertTrue(prompt.question.lowercased().contains("hook") || prompt.question.lowercased().contains("built"),
                      "Got: \(prompt.question)")
    }

    func testMidLifePromptIsNonJudgmental() {
        let p = UserProfile(birthYear: currentYear - 45, gender: .male)
        let prompt = ReflectionEngine.prompt(for: p, appName: app, todaySeconds: 0)
        // Should not contain shame-trigger words
        let q = prompt.question.lowercased()
        XCTAssertFalse(q.contains("wasting") || q.contains("lazy") || q.contains("stop"),
                       "Prompt should not shame. Got: \(prompt.question)")
    }

    // MARK: - Helper

    private func assertValid(_ prompt: ReflectionEngine.Prompt, file: StaticString = #file, line: UInt = #line) {
        XCTAssertFalse(prompt.question.isEmpty,     "question is empty",      file: file, line: line)
        XCTAssertFalse(prompt.hint.isEmpty,         "hint is empty",          file: file, line: line)
        XCTAssertFalse(prompt.continueLabel.isEmpty,"continueLabel is empty", file: file, line: line)
    }
}
