import SwiftData

extension Arming {
    /// The run every trigger in the app calls. Each run asks iOS for the next background refresh.
    static let shared = Arming(
        openStore: { try SharedStore.container() },
        calendarReader: EventKitReader(),
        alarmScheduler: AlarmKitScheduler(),
        notifier: UserNotificationsNotifier(),
        clock: SystemClock(),
        afterEachRun: BackgroundRefresh.schedule
    )
}

/// The one SwiftData store the screens and the Arming run share.
enum SharedStore {
    private static var opened: ModelContainer?

    /// Throws instead of crashing, and tries again on the next call: before the first unlock after a reboot
    /// the store's file can't be opened.
    static func container() throws -> ModelContainer {
        if let opened { return opened }
        let container = try ModelContainer(for: ShiftType.self, ChosenCalendar.self, Skip.self, ArmingRecord.self)
        opened = container
        return container
    }
}
