import Foundation
import DeviceActivity

struct LifetimeImpact {
    let dailyAverageSeconds: TimeInterval
    let yearsAtCurrentRate: Double
    let yearsRecoverableAt50Percent: Double
    let relationalStake: String          // The near-term concrete framing
}

struct AppImpact {
    let appName: String
    let todaySeconds: TimeInterval
    let weeklyAverageSeconds: TimeInterval
    let relationalStake: String
}

struct LifetimeImpactCalculator {
    let profile: UserProfile

    // Converts raw total screen seconds over past 365 days into a lifetime projection.
    func calculate(totalSecondsLastYear: TimeInterval) -> LifetimeImpact {
        let dailyAvg = totalSecondsLastYear / 365
        let secondsPerYear = 365.0 * 24 * 3600
        let yearsAtRate = (dailyAvg * Double(profile.yearsRemaining) * 365) / secondsPerYear
        let yearsRecoverable = yearsAtRate * 0.5

        return LifetimeImpact(
            dailyAverageSeconds: dailyAvg,
            yearsAtCurrentRate: yearsAtRate,
            yearsRecoverableAt50Percent: yearsRecoverable,
            relationalStake: relationalStake(dailyAvgSeconds: dailyAvg)
        )
    }

    func appImpact(appName: String, todaySeconds: TimeInterval, weeklyTotalSeconds: TimeInterval) -> AppImpact {
        let weeklyAvg = weeklyTotalSeconds / 7
        return AppImpact(
            appName: appName,
            todaySeconds: todaySeconds,
            weeklyAverageSeconds: weeklyAvg,
            relationalStake: appRelationalStake(appName: appName, todaySeconds: todaySeconds)
        )
    }

    // Research finding: near-term concrete stakes land harder than abstract lifetime stats.
    private func relationalStake(dailyAvgSeconds: TimeInterval) -> String {
        let hours = dailyAvgSeconds / 3600
        let formattedHours = String(format: "%.1f", hours)

        switch profile.ageGroup {
        case .teen:
            return "That's \(formattedHours) hours a day you could be sleeping, training, or actually creating something."
        case .youngAdult:
            switch profile.gender {
            case .female:
                return "That's \(formattedHours) hours daily — the equivalent of a part-time job spent on someone else's content."
            case .male, .preferNotToSay:
                return "At \(formattedHours) hours a day, you're handing \(annualWeeks(dailyAvgSeconds: dailyAvgSeconds)) weeks a year to an algorithm."
            }
        case .midLife:
            let kidsAge = estimatedKidsAge()
            if let age = kidsAge {
                let summersLeft = max(0, 18 - age)
                return "Your kid is around \(age). You have roughly \(summersLeft) summers before they leave. That's \(formattedHours) hours of those days going to your phone."
            }
            return "That's \(formattedHours) hours a day you won't get back — time that could be presence, not scrolling."
        }
    }

    private func appRelationalStake(appName: String, todaySeconds: TimeInterval) -> String {
        let minutes = Int(todaySeconds / 60)
        guard minutes > 0 else { return "First time today." }

        switch profile.ageGroup {
        case .teen:
            return "You've already spent \(minutes) min on \(appName) today."
        case .youngAdult:
            return "\(minutes) min on \(appName) today — that's a workout, a chapter, or a real conversation."
        case .midLife:
            return "You've been on \(appName) for \(minutes) min today."
        }
    }

    private func annualWeeks(dailyAvgSeconds: TimeInterval) -> Int {
        Int((dailyAvgSeconds * 365) / (7 * 24 * 3600))
    }

    // Rough heuristic — mid-life users with our app are often parents.
    // In a real app this would come from an optional onboarding question.
    private func estimatedKidsAge() -> Int? {
        let userAge = Calendar.current.component(.year, from: Date()) - profile.birthYear
        guard userAge >= 28 else { return nil }
        // Assume first child at ~28; purely illustrative default.
        return userAge - 28
    }
}

// Formatting helpers used across the UI.
extension TimeInterval {
    var durationString: String {
        let h = Int(self) / 3600
        let m = (Int(self) % 3600) / 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }
}
