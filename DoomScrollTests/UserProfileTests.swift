import XCTest
@testable import DoomScroll

final class UserProfileTests: XCTestCase {

    private let currentYear = Calendar.current.component(.year, from: Date())

    // MARK: - ageGroup bucketing

    func testAgeGroupTeen_at15() {
        let p = UserProfile(birthYear: currentYear - 15, gender: .male)
        XCTAssertEqual(p.ageGroup, .teen)
    }

    func testAgeGroupTeen_at18() {
        let p = UserProfile(birthYear: currentYear - 18, gender: .female)
        XCTAssertEqual(p.ageGroup, .teen)
    }

    func testAgeGroupYoungAdult_at19() {
        let p = UserProfile(birthYear: currentYear - 19, gender: .male)
        XCTAssertEqual(p.ageGroup, .youngAdult)
    }

    func testAgeGroupYoungAdult_at30() {
        let p = UserProfile(birthYear: currentYear - 30, gender: .female)
        XCTAssertEqual(p.ageGroup, .youngAdult)
    }

    func testAgeGroupYoungAdult_at35() {
        let p = UserProfile(birthYear: currentYear - 35, gender: .male)
        XCTAssertEqual(p.ageGroup, .youngAdult)
    }

    func testAgeGroupMidLife_at36() {
        let p = UserProfile(birthYear: currentYear - 36, gender: .male)
        XCTAssertEqual(p.ageGroup, .midLife)
    }

    func testAgeGroupMidLife_at60() {
        let p = UserProfile(birthYear: currentYear - 60, gender: .female)
        XCTAssertEqual(p.ageGroup, .midLife)
    }

    // MARK: - yearsRemaining

    func testYearsRemainingIsPositiveForYoungPerson() {
        let p = UserProfile(birthYear: currentYear - 25, gender: .male, lifeExpectancy: 82)
        XCTAssertGreaterThan(p.yearsRemaining, 0)
    }

    func testYearsRemainingApproximation() {
        // Birth date is approximated as January 1 of birthYear (we only collect the year).
        // Result is exact for a Jan 1 birthday; up to 364 days off for a Dec 31 birthday.
        let p = UserProfile(birthYear: currentYear - 30, gender: .male, lifeExpectancy: 82)
        XCTAssertEqual(p.yearsRemaining, 52, accuracy: 1.0)
    }

    func testYearsRemainingIsZeroWhenAgeEqualsLifeExpectancy() {
        let p = UserProfile(birthYear: currentYear - 82, gender: .male, lifeExpectancy: 82)
        XCTAssertEqual(p.yearsRemaining, 0)
    }

    func testYearsRemainingIsZeroWhenAgePastLifeExpectancy() {
        let p = UserProfile(birthYear: currentYear - 90, gender: .female, lifeExpectancy: 82)
        XCTAssertEqual(p.yearsRemaining, 0)
    }

    func testCustomLifeExpectancy() {
        let p = UserProfile(birthYear: currentYear - 40, gender: .male, lifeExpectancy: 100)
        XCTAssertEqual(p.yearsRemaining, 60, accuracy: 1.0)
    }

    // MARK: - Codable round-trip

    func testCodableRoundTrip_allGenders() throws {
        for gender in UserProfile.Gender.allCases {
            let original = UserProfile(birthYear: 1990, gender: gender, lifeExpectancy: 85)
            let data = try JSONEncoder().encode(original)
            let decoded = try JSONDecoder().decode(UserProfile.self, from: data)

            XCTAssertEqual(decoded.birthYear, original.birthYear)
            XCTAssertEqual(decoded.gender, original.gender)
            XCTAssertEqual(decoded.lifeExpectancy, original.lifeExpectancy)
        }
    }

    func testDefaultLifeExpectancyIs82() {
        let p = UserProfile(birthYear: 1990, gender: .male)
        XCTAssertEqual(p.lifeExpectancy, 82)
    }

    // MARK: - Gender display names

    func testGenderDisplayNames() {
        XCTAssertEqual(UserProfile.Gender.male.displayName, "Male")
        XCTAssertEqual(UserProfile.Gender.female.displayName, "Female")
        XCTAssertEqual(UserProfile.Gender.preferNotToSay.displayName, "Prefer not to say")
    }

    // MARK: - Persistence via SharedDefaults

    func testSaveAndLoad() throws {
        let testSuite = "test.doomscroll.profile"
        UserDefaults.standard.removePersistentDomain(forName: testSuite)
        SharedDefaults.store = UserDefaults(suiteName: testSuite) ?? .standard
        defer { UserDefaults.standard.removePersistentDomain(forName: testSuite) }

        let original = UserProfile(birthYear: 1988, gender: .female, lifeExpectancy: 84)
        original.save()
        let loaded = UserProfile.load()

        XCTAssertNotNil(loaded)
        XCTAssertEqual(loaded?.birthYear, original.birthYear)
        XCTAssertEqual(loaded?.gender, original.gender)
        XCTAssertEqual(loaded?.lifeExpectancy, original.lifeExpectancy)
    }

    func testLoadReturnsNilWhenNothingSaved() {
        let testSuite = "test.doomscroll.profile.empty"
        UserDefaults.standard.removePersistentDomain(forName: testSuite)
        SharedDefaults.store = UserDefaults(suiteName: testSuite) ?? .standard
        defer { UserDefaults.standard.removePersistentDomain(forName: testSuite) }

        XCTAssertNil(UserProfile.load())
    }
}
