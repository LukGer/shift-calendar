import Foundation

/// Stands in until the stale-Arming notification is built.
struct NoNotifier: Notifier {
    func replaceStaleArmingNotification(firingAt date: Date) async {}
}
