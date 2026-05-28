import Foundation

struct UserProfile: Codable {
    var birthYear: Int
    var gender: Gender
    var lifeExpectancy: Int = 82     // Editable; WHO global average default

    enum Gender: String, Codable, CaseIterable {
        case male, female, preferNotToSay

        var displayName: String {
            switch self {
            case .male: return "Male"
            case .female: return "Female"
            case .preferNotToSay: return "Prefer not to say"
            }
        }
    }

    var ageGroup: AgeGroup {
        switch currentAge {
        case ..<19: return .teen
        case 19..<36: return .youngAdult
        default: return .midLife
        }
    }

    enum AgeGroup {
        case teen, youngAdult, midLife
    }

    var yearsRemaining: Double {
        max(0, Double(lifeExpectancy) - Double(currentAge))
    }

    // Approximates birth date as January 1 of birthYear since we only collect the year,
    // not month/day. Accurate to within 0–364 days — sufficient for age-group bucketing.
    private var currentAge: Int {
        let birthDate = Calendar.current.date(from: DateComponents(year: birthYear)) ?? Date()
        return Calendar.current.dateComponents([.year], from: birthDate, to: Date()).year ?? 0
    }
}

extension UserProfile {
    static let storageKey = "userProfile"

    static func load() -> UserProfile? {
        guard
            let data = SharedDefaults.store.data(forKey: storageKey),
            let profile = try? JSONDecoder().decode(UserProfile.self, from: data)
        else { return nil }
        return profile
    }

    func save() {
        let data = try? JSONEncoder().encode(self)
        SharedDefaults.store.set(data, forKey: UserProfile.storageKey)
    }
}
