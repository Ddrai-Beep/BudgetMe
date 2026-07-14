import Foundation
import UserNotifications

/// Schedules local notifications reminding the user before a subscription renews.
/// No backend or push certificates needed — these fire on-device even when the app is closed.
final class NotificationManager {
    static let shared = NotificationManager()

    func requestAuthorization() {
        UNUserNotificationCenter.current()
            .requestAuthorization(options: [.alert, .sound, .badge]) { _, _ in }
    }

    /// Clears existing reminders and reschedules one per subscription
    /// (3 days before renewal; 7 days for annual).
    func scheduleRenewalReminders(subscriptions: [Subscription], currencyCode: String) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()

        let cal = Calendar.current
        for sub in subscriptions {
            let leadDays = sub.cycle == .annual ? 7 : 3
            guard let fireDate = cal.date(byAdding: .day, value: -leadDays, to: sub.renewalDate),
                  fireDate > Date() else { continue }

            let content = UNMutableNotificationContent()
            content.title = "\(sub.name) renews soon"
            content.body = "\(Money.format(sub.amount, code: currencyCode)) on \(sub.renewalDate.formatted(date: .abbreviated, time: .omitted))."
            content.sound = .default

            let comps = cal.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
            let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: false)
            let request = UNNotificationRequest(
                identifier: "renewal-\(sub.id.uuidString)",
                content: content,
                trigger: trigger
            )
            center.add(request)
        }
    }
}
