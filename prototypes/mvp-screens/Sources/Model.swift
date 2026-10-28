// PROTOTYPE: in-memory stub data. No EventKit, no AlarmKit, no persistence.
import SwiftUI

struct Alarm: Identifiable {
    let id = UUID()
    var time: Date
}

struct ShiftType: Identifiable {
    let id = UUID()
    var name: String
    var shortcut: String
    var color: Color
    var alarms: [Alarm]

    var title: String { name.isEmpty ? shortcut : name }
    var alarmSummary: String { alarms.isEmpty ? "Rings nothing" : alarms.map(\.time.clock).joined(separator: " · ") }
}

struct CalendarEvent {
    let date: Date
    let title: String
}

struct Shift: Identifiable {
    let date: Date
    let type: ShiftType
    let skipped: Bool
    var id: Date { date }
}

struct SourceCalendar: Identifiable {
    let name: String
    var chosen: Bool
    var id: String { name }
}

enum Screen: String { case onboarding, home, types, editor }

@Observable
final class Store {
    var shiftTypes: [ShiftType]
    var calendars: [SourceCalendar]
    var calendarAccess: Bool
    var alarmAccess: Bool
    var onboarded: Bool
    private var skippedDates: Set<Date>
    private let events: [CalendarEvent]
    private let eventCounts = ["td": 14, "nd": 9, "sd": 3, "u": 2, "fb": 2]

    init(screen: Screen) {
        let fresh = screen == .onboarding
        func alarms(_ times: (Int, Int)...) -> [Alarm] { fresh ? [] : times.map { Alarm(time: .at($0.0, $0.1)) } }
        shiftTypes = [
            ShiftType(name: fresh ? "" : "Tagdienst", shortcut: "td", color: .orange, alarms: alarms((5, 0), (5, 10), (5, 20))),
            ShiftType(name: fresh ? "" : "Nachtdienst", shortcut: "nd", color: .indigo, alarms: alarms((16, 30), (16, 45))),
            ShiftType(name: fresh ? "" : "Spätdienst", shortcut: "sd", color: .teal, alarms: alarms((10, 45))),
            ShiftType(name: fresh ? "" : "Urlaub", shortcut: "u", color: .gray, alarms: []),
        ]
        events = [(1, "td"), (2, "td"), (3, "nd"), (4, "nd"), (5, "fb"), (6, "u"), (7, "SD")]
            .map { CalendarEvent(date: .day($0.0), title: $0.1) }
        skippedDates = fresh ? [] : [.day(2)]
        calendars = [SourceCalendar(name: "Dienstplan", chosen: !fresh), SourceCalendar(name: "Home", chosen: false), SourceCalendar(name: "Birthdays", chosen: false)]
        calendarAccess = !fresh
        alarmAccess = !fresh
        onboarded = !fresh
    }

    var window: [Date] { (1...7).map(Date.day) }

    var shifts: [Shift] {
        guard calendarAccess else { return [] }
        return events.compactMap { event in
            matchingType(event.title).map { Shift(date: event.date, type: $0, skipped: skippedDates.contains(event.date)) }
        }
    }

    var unmappedShortcuts: [(shortcut: String, count: Int)] {
        eventCounts.filter { matchingType($0.key) == nil }.sorted { $0.key < $1.key }.map { ($0.key, $0.value) }
    }

    var chosenCalendarNames: String {
        let names = calendars.filter(\.chosen).map(\.name)
        return names.isEmpty ? "No calendar" : names.joined(separator: ", ")
    }

    func shift(on date: Date) -> Shift? { shifts.first { $0.date == date } }

    func toggleSkip(_ shift: Shift) {
        if skippedDates.remove(shift.date) == nil { skippedDates.insert(shift.date) }
    }

    func addShiftType(shortcut: String = "") -> Int {
        shiftTypes.append(ShiftType(name: "", shortcut: shortcut, color: .pink, alarms: []))
        return shiftTypes.count - 1
    }

    private func matchingType(_ title: String) -> ShiftType? {
        let key = title.trimmingCharacters(in: .whitespaces).lowercased()
        return shiftTypes.first { $0.shortcut.lowercased() == key }
    }
}

extension Date {
    static func at(_ hour: Int, _ minute: Int) -> Date {
        Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: .now)!
    }

    static func day(_ offset: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: offset, to: Calendar.current.startOfDay(for: .now))!
    }

    var clock: String {
        let parts = Calendar.current.dateComponents([.hour, .minute], from: self)
        return String(format: "%02d:%02d", parts.hour!, parts.minute!)
    }

    var dayTitle: String {
        Calendar.current.isDateInTomorrow(self) ? "Tomorrow" : formatted(.dateTime.weekday(.wide).day().month(.abbreviated))
    }
}
