import Foundation
@testable import ShiftAlarm

@MainActor
final class FakeCalendarStore: CalendarStore {
    var hasFullAccess = true
    var deviceCalendars = [
        DeviceCalendar(identifier: "dienste", title: "Dienste", sourceIdentifier: "icloud", isEditable: true),
    ]
    var eventsByCalendar: [String: [CalendarEvent]] = [:]

    func calendars() -> [DeviceCalendar] {
        deviceCalendars
    }

    /// Like EventKit, each event reports the calendar it is in.
    func events(inCalendars identifiers: [String], from start: Date, to end: Date) -> [CalendarEvent] {
        identifiers.flatMap { identifier in
            (eventsByCalendar[identifier] ?? []).map { event in
                var event = event
                event.calendarIdentifier = identifier
                return event
            }
        }
    }

    /// Like EventKit, the event ends at 23:59:59 on its day.
    func addAllDayEvent(titled title: String, on day: Date, inCalendar identifier: String) {
        eventsByCalendar[identifier, default: []].append(CalendarEvent(
            identifier: UUID().uuidString, calendarIdentifier: identifier, isRecurring: false, title: title,
            startDate: day, endDate: day.addingTimeInterval(24 * 60 * 60 - 1), isAllDay: true))
    }

    func deleteEvent(identifier: String) {
        for calendar in eventsByCalendar.keys {
            eventsByCalendar[calendar]?.removeAll { $0.identifier == identifier }
        }
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
