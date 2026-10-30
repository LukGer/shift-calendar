import UserNotifications

/// Keeps one stale-Arming notification pending. Tapping it opens the app, which arms on every return to the foreground.
struct UserNotificationsNotifier: Notifier {
    private static let staleArmingIdentifier = "stale-arming"
    private var center: UNUserNotificationCenter { .current() }

    func permission() async -> NotificationPermission {
        NotificationPermission(await center.notificationSettings().authorizationStatus)
    }

    /// Asks for permission to notify the first time; afterwards returns without asking.
    func requestAuthorization() async {
        _ = try? await center.requestAuthorization(options: [.alert, .sound])
    }

    /// Adding a request with the same identifier replaces the pending one. A warning already delivered is out of date
    /// once a run has armed, so it goes too.
    func replaceStaleArmingNotification(firingAt date: Date) async {
        let content = UNMutableNotificationContent()
        content.title = "Shift Alarm"
        content.body = "Your shift alarms may be out of date. Tap to check."
        content.sound = .default
        let trigger = UNTimeIntervalNotificationTrigger(timeInterval: max(1, date.timeIntervalSinceNow), repeats: false)
        center.removeDeliveredNotifications(withIdentifiers: [Self.staleArmingIdentifier])
        try? await center.add(UNNotificationRequest(identifier: Self.staleArmingIdentifier, content: content, trigger: trigger))
    }
}

nonisolated enum NotificationPermission {
    case allowed, notAsked, denied

    init(_ status: UNAuthorizationStatus) {
        switch status {
        case .notDetermined: self = .notAsked
        case .denied: self = .denied
        default: self = .allowed
        }
    }
}
