import Foundation
import SwiftUI

/// The Arming run's only ways to reach the system. Each has an adapter in the app and a fake in the tests.

protocol CalendarReader {
    func events(inCalendars identifiers: [String], from start: Date, to end: Date) -> [CalendarEvent]
}

protocol AlarmScheduler {
    /// Only this app's alarms, never the Clock app's.
    func alarmIDs() throws -> Set<UUID>
    func schedule(_ alarm: WantedAlarm) async throws
    func cancel(id: UUID) throws
}

protocol Notifier {
    func replaceStaleArmingNotification(firingAt date: Date) async
}

protocol WallClock {
    var now: Date { get }
    /// The device's current calendar and time zone.
    var calendar: Calendar { get }
}

nonisolated struct CalendarEvent {
    var title: String
    var startDate: Date
    var endDate: Date
    var isAllDay: Bool
}

struct WantedAlarm: Equatable {
    let id: UUID
    let instant: Date
    let title: String
    let tint: Color
}
