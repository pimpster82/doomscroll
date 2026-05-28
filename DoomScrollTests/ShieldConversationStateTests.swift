import XCTest
@testable import DoomScroll

final class ShieldConversationStateTests: XCTestCase {

    private static let testSuite = "test.doomscroll.shield"

    override func setUp() {
        super.setUp()
        UserDefaults.standard.removePersistentDomain(forName: Self.testSuite)
        SharedDefaults.store = UserDefaults(suiteName: Self.testSuite) ?? .standard
    }

    override func tearDown() {
        UserDefaults.standard.removePersistentDomain(forName: Self.testSuite)
        super.tearDown()
    }

    // MARK: - Default values

    func testDefaultStepIsImpact() {
        XCTAssertEqual(ShieldConversationState().step, .impact)
    }

    func testDefaultSessionBudgetIsZero() {
        XCTAssertEqual(ShieldConversationState().sessionBudgetSeconds, 0)
    }

    // MARK: - Codable round-trip (in-memory)

    func testCodableRoundTrip_impactStep() throws {
        var state = ShieldConversationState()
        state.step = .impact
        state.sessionBudgetSeconds = 0

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(ShieldConversationState.self, from: data)
        XCTAssertEqual(decoded.step, .impact)
        XCTAssertEqual(decoded.sessionBudgetSeconds, 0)
    }

    func testCodableRoundTrip_reflectionStep() throws {
        var state = ShieldConversationState()
        state.step = .reflection
        state.sessionBudgetSeconds = 0

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(ShieldConversationState.self, from: data)
        XCTAssertEqual(decoded.step, .reflection)
    }

    func testCodableRoundTrip_commitStep_withBudget() throws {
        var state = ShieldConversationState()
        state.step = .commit
        state.sessionBudgetSeconds = 900

        let data = try JSONEncoder().encode(state)
        let decoded = try JSONDecoder().decode(ShieldConversationState.self, from: data)
        XCTAssertEqual(decoded.step, .commit)
        XCTAssertEqual(decoded.sessionBudgetSeconds, 900)
    }

    // MARK: - Save / load via SharedDefaults

    func testSaveAndLoad() {
        var state = ShieldConversationState()
        state.step = .commit
        state.sessionBudgetSeconds = 1800

        state.save(for: "token_abc")
        let loaded = ShieldConversationState.load(for: "token_abc")

        XCTAssertEqual(loaded.step, .commit)
        XCTAssertEqual(loaded.sessionBudgetSeconds, 1800)
    }

    func testLoadUnknownTokenReturnsDefault() {
        let state = ShieldConversationState.load(for: "no_such_token")
        XCTAssertEqual(state.step, .impact)
        XCTAssertEqual(state.sessionBudgetSeconds, 0)
    }

    func testTokensAreStoredIndependently() {
        var stateA = ShieldConversationState()
        stateA.step = .commit
        stateA.save(for: "tokenA")

        var stateB = ShieldConversationState()
        stateB.step = .reflection
        stateB.save(for: "tokenB")

        XCTAssertEqual(ShieldConversationState.load(for: "tokenA").step, .commit)
        XCTAssertEqual(ShieldConversationState.load(for: "tokenB").step, .reflection)
    }

    func testOverwritingSavePersistsLatestValue() {
        var state = ShieldConversationState()
        state.step = .reflection
        state.save(for: "token_x")

        state.step = .commit
        state.sessionBudgetSeconds = 900
        state.save(for: "token_x")

        let loaded = ShieldConversationState.load(for: "token_x")
        XCTAssertEqual(loaded.step, .commit)
        XCTAssertEqual(loaded.sessionBudgetSeconds, 900)
    }

    // MARK: - Step sequence (transition coverage)

    func testStepRawValues() {
        XCTAssertEqual(ShieldConversationState.ConversationStep.impact.rawValue,     "impact")
        XCTAssertEqual(ShieldConversationState.ConversationStep.reflection.rawValue, "reflection")
        XCTAssertEqual(ShieldConversationState.ConversationStep.commit.rawValue,     "commit")
    }

    func testAllStepsRoundTripThroughStorage() {
        for step in [ShieldConversationState.ConversationStep.impact, .reflection, .commit] {
            var state = ShieldConversationState()
            state.step = step
            state.save(for: "step_\(step.rawValue)")
            XCTAssertEqual(ShieldConversationState.load(for: "step_\(step.rawValue)").step, step)
        }
    }

    // MARK: - sessionBudgetSeconds is set at reflection → commit transition

    func testSessionBudgetSecondsIsWrittenBefore900SecondSession() {
        var state = ShieldConversationState()
        state.step = .commit
        state.sessionBudgetSeconds = 900
        state.save(for: "budget_test")

        let loaded = ShieldConversationState.load(for: "budget_test")
        XCTAssertEqual(loaded.sessionBudgetSeconds, 900,
                       "sessionBudgetSeconds must be 900 before reaching .commit — re-shield depends on it")
    }
}
