import Foundation
// UNNotificationSettings is not Sendable in newer SDKs, so awaiting
// notificationSettings() from a @MainActor context is a Swift 6 error
// without @preconcurrency.
@preconcurrency import UserNotifications

@MainActor
protocol SprintNotifying: AnyObject {
    func prepareAuthorization()
    func notifyTimeUp(taskTitle: String)
}

/// Posts a user notification when the countdown reaches zero, so a sprint
/// running in the background (panel hidden or compact) still surfaces.
/// The completion sound cue stays separate; the notification itself is silent.
@MainActor
final class UserNotificationSprintNotifier: SprintNotifying {
    func prepareAuthorization() {
        Task {
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()
            guard settings.authorizationStatus == .notDetermined else {
                return
            }

            _ = try? await center.requestAuthorization(options: [.alert])
        }
    }

    func notifyTimeUp(taskTitle: String) {
        Task {
            let center = UNUserNotificationCenter.current()
            let settings = await center.notificationSettings()
            guard settings.authorizationStatus == .authorized
                    || settings.authorizationStatus == .provisional else {
                return
            }

            let content = UNMutableNotificationContent()
            content.title = "Time's up"
            let trimmed = taskTitle.trimmingCharacters(in: .whitespacesAndNewlines)
            content.body = trimmed.isEmpty
                ? "Your sprint reached its planned time — now in overtime."
                : "\(trimmed) reached its planned time — now in overtime."

            let request = UNNotificationRequest(
                identifier: "one-clock.time-up.\(UUID().uuidString)",
                content: content,
                trigger: nil
            )
            try? await center.add(request)
        }
    }
}
