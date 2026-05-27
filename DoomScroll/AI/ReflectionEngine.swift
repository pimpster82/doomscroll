import Foundation

// Generates the reflective question shown on step 2 of the shield conversation.
// Adapts tone and framing to the user's age group and gender based on behavioral research.
struct ReflectionEngine {

    struct Prompt {
        let question: String        // The reflective question shown to the user
        let hint: String            // Placeholder/hint in the response area
        let continueLabel: String   // Button label for proceeding
    }

    static func prompt(for profile: UserProfile, appName: String, todaySeconds: TimeInterval) -> Prompt {
        switch profile.ageGroup {
        case .teen:
            return teenPrompt(gender: profile.gender, appName: appName)
        case .youngAdult:
            return youngAdultPrompt(gender: profile.gender, appName: appName, todaySeconds: todaySeconds)
        case .midLife:
            return midLifePrompt(gender: profile.gender, appName: appName)
        }
    }

    // Teens: validate the social/emotional pull, frame as autonomy vs algorithm.
    // Research: autonomy + "outsmart the system" resonates; parental/clinical tone backfires.
    private static func teenPrompt(gender: UserProfile.Gender, appName: String) -> Prompt {
        switch gender {
        case .female:
            return Prompt(
                question: "What's actually pulling you to \(appName) right now?",
                hint: "Bored, stressed, habit, something else...",
                continueLabel: "I know what I'm doing"
            )
        case .male, .preferNotToSay:
            return Prompt(
                question: "\(appName) is built to hook you. What are you actually after right now?",
                hint: "Boredom, procrastination, just habit...",
                continueLabel: "I'm choosing this"
            )
        }
    }

    // Young adults: concrete opportunity cost, non-preachy.
    // Research: they know scrolling is bad; reframe as trade, not lecture.
    private static func youngAdultPrompt(gender: UserProfile.Gender, appName: String, todaySeconds: TimeInterval) -> Prompt {
        let minutes = max(1, Int(todaySeconds / 60))
        switch gender {
        case .female:
            return Prompt(
                question: "You've got \(minutes) min on \(appName) today. What do you actually want right now — connection, a break, or just habit?",
                hint: "Be honest with yourself...",
                continueLabel: "Open it anyway"
            )
        case .male, .preferNotToSay:
            return Prompt(
                question: "What's the trade? \(minutes) more min on \(appName), or something you'd actually feel good about later?",
                hint: "What are you giving up?",
                continueLabel: "I'll take the trade"
            )
        }
    }

    // Mid-life: presence and legacy framing, no shame, relational stakes.
    // Research: "time you won't get back" + near-term family stakes outperforms abstract stats.
    private static func midLifePrompt(gender: UserProfile.Gender, appName: String) -> Prompt {
        switch gender {
        case .female:
            return Prompt(
                question: "What's pulling you to \(appName) right now? Sometimes it's exactly what you need — sometimes it's just the easiest thing.",
                hint: "What's really going on?",
                continueLabel: "Open it"
            )
        case .male, .preferNotToSay:
            return Prompt(
                question: "Is \(appName) the best use of this moment, or is this just the path of least resistance?",
                hint: "What else could you be doing?",
                continueLabel: "Open it anyway"
            )
        }
    }
}

// MARK: - AI-enhanced prompts (iOS 26 Foundation Models / CoreML fallback)

// When on-device AI is available, the static prompts above are replaced with
// dynamically generated ones. The static versions remain as the fallback.
@available(iOS 26.0, *)
struct AIReflectionEngine {

    // System prompt instructs the model to act as a supportive, non-judgmental
    // reflection partner — never preachy, never clinical.
    static func systemPrompt(for profile: UserProfile) -> String {
        let ageDesc: String
        switch profile.ageGroup {
        case .teen: ageDesc = "a teenager"
        case .youngAdult: ageDesc = "a young adult in their 20s or early 30s"
        case .midLife: ageDesc = "an adult in their 40s or 50s"
        }

        return """
        You are a brief, warm, non-judgmental reflection prompt generator for a screen time app.
        The user is \(ageDesc)\(profile.gender == .female ? ", female" : profile.gender == .male ? ", male" : "").

        Generate ONE short reflective question (max 20 words) that:
        - Opens with curiosity, not challenge
        - Validates the emotional pull of the app without shaming
        - Surfaces a concrete near-term trade-off personal to this user
        - Never sounds like a parent, doctor, or productivity app
        - Ends with the user feeling like they're making a conscious choice

        Return only the question. No preamble, no explanation.
        """
    }

    static func userMessage(appName: String, todaySeconds: TimeInterval) -> String {
        let minutes = max(1, Int(todaySeconds / 60))
        return "App: \(appName). Time today: \(minutes) minutes. Generate a reflection question."
    }
}
