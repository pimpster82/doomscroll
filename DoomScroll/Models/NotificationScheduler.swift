import UserNotifications
import Foundation

// Schedules streak milestone and daily check-in notifications.
// Max 1 notification per day. All notifications are opt-in — permission is requested
// once on first Dashboard load; user can revoke in Settings at any time.
struct NotificationScheduler {

    // MARK: - Permission

    static func requestPermissionIfNeeded() {
        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .notDetermined else { return }
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { _, _ in }
        }
    }

    // MARK: - Streak milestones

    static func scheduleStreakMilestoneIfNeeded(streak: Int) {
        let milestones = [3, 7, 14, 30]
        guard milestones.contains(streak) else { return }

        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else { return }

            let content = UNMutableNotificationContent()
            content.sound = .default

            switch streak {
            case 3:
                content.title = "3-day streak 🔥"
                content.body = "Three days without hitting your limit. That's real."
            case 7:
                content.title = "One week streak"
                content.body = "Seven days of staying in control. Square Eyes is proud."
            case 14:
                content.title = "Two weeks straight"
                content.body = "14 days. You've changed a habit, not just delayed it."
            default: // 30
                content.title = "30 days 🏆"
                content.body = "A month. Most apps want your attention — you took it back."
            }

            let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 1, repeats: false)
            let request = UNNotificationRequest(
                identifier: "streak.milestone.\(streak)",
                content: content,
                trigger: trigger
            )
            UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
        }
    }

    // MARK: - Daily check-in

    // Schedules (or replaces) tomorrow's 9am check-in notification.
    // Only scheduled when the current streak is > 0 — silent days get no nudge.
    static func scheduleDailyCheckIn(streak: Int) {
        let identifier = "daily.checkin"
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])

        guard streak > 0 else { return }

        UNUserNotificationCenter.current().getNotificationSettings { settings in
            guard settings.authorizationStatus == .authorized else { return }

            let content = UNMutableNotificationContent()
            content.title = "Day \(streak + 1) incoming"
            content.body = "Keep the streak going — open DoomScroll to check in."
            content.sound = .default

            var components = DateComponents()
            components.hour = 9
            components.minute = 0

            let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
            let request = UNNotificationRequest(identifier: identifier, content: content, trigger: trigger)
            UNUserNotificationCenter.current().add(request, withCompletionHandler: nil)
        }
    }

    // Call when the streak is broken so the pending check-in is cancelled.
    static func cancelDailyCheckIn() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: ["daily.checkin"])
    }
}
