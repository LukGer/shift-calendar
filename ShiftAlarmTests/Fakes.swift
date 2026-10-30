import Foundation
@testable import ShiftAlarm

@MainActor
final class FakeCalendarReader: CalendarReader {
    var hasFullAccess = true
    var deviceCalendars = [DeviceCalendar(identifier: "dienste", title: "Dienste", sourceIdentifier: "icloud")]
    var eventsByCalendar: [String: [CalendarEvent]] = [:]

    func calendars() -> [DeviceCalendar] {
        deviceCalendars
    }

    func events(inCalendars identifiers: [String], from start: Date, to end: Date) -> [CalendarEvent] {
        identifiers.flatMap { eventsByCalendar[$0] ?? [] }
    }
}

/// Behaves like AlarmKit: scheduling an ID that is already armed throws.
@MainActor
final class FakeAlarmScheduler: AlarmScheduler {
    enum Call: Equatable {
        case schedule(UUID)
        case cancel(UUID)
    }

    struct AlreadyArmed: Error {}
    struct CancelFailed: Error {}

    private(set) var armed: [UUID: WantedAlarm] = [:]
    private(set) var calls: [Call] = []
    var isAuthorized = true
    var cancellingFails = false

    func arm(_ alarm: WantedAlarm) {
        armed[alarm.id] = alarm
    }

    func alarmIDs() throws -> Set<UUID> {
        Set(armed.keys)
    }

    func schedule(_ alarm: WantedAlarm) async throws {
        await Task.yield()
        guard armed[alarm.id] == nil else { throw AlreadyArmed() }
        calls.append(.schedule(alarm.id))
        armed[alarm.id] = alarm
    }

    func cancel(id: UUID) throws {
        if cancellingFails { throw CancelFailed() }
        calls.append(.cancel(id))
        armed[id] = nil
    }
}

@MainActor
final class FakeNotifier: Notifier {
    private(set) var staleArmingNotificationDate: Date?

    func replaceStaleArmingNotification(firingAt date: Date) async {
        staleArmingNotificationDate = date
    }
}

@MainActor
final class FixedClock: WallClock {
    var now: Date
    let calendar: Calendar

    init(now: Date, calendar: Calendar) {
        self.now = now
        self.calendar = calendar
    }
}
