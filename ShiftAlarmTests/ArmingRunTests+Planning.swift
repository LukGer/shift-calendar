import Foundation
import SwiftData
import Testing
@testable import ShiftAlarm

/// Planning: putting a Shift on a date or taking it off from the day sheet, then arming.
/// "Now" is 2031-03-02 20:00, so the Arming Window covers 2031-03-02 to 2031-03-09.
extension ArmingRunTests {
    @Test(arguments: [
        ("td", "2031-03-03", ["2031-03-03 05:00 Tagdienst"]),
        ("nd", "2031-03-09", ["2031-03-09 18:30 Nachtdienst"]),
        ("hrn", "2031-03-20", []),
        ("e6", "2031-03-03", []),
    ])
    func tickingAShiftTypeWritesItsShortcutIntoThePlanningCalendarAndArmsIt(
        shortcut: String, date: String, expectedAlarms: [String]
    ) async throws {
        addHerShiftTypes()

        try await plan(shortcut, on: date)

        #expect(calendarHolds == ["dienste \(date) \(shortcut)"])
        #expect(armedAlarms == expectedAlarms)
    }

    // MARK: - Fixtures

    var planning: Planning {
        Planning(context: container.mainContext, calendarStore: calendarStore, clock: clock, arming: arming)
    }

    func plan(_ shortcut: String, on date: String) async throws {
        try await planning.toggleOn(try shiftType(shortcut), on: Self.instant("\(date) 00:00"))
    }

    func shiftType(_ shortcut: String) throws -> ShiftType {
        try #require(try container.mainContext.fetch(FetchDescriptor<ShiftType>()).first { $0.shortcut == shortcut })
    }

    /// "dienste 2031-03-03 td" for each event in the fake calendar, with a multi-day one's dates joined by "…".
    var calendarHolds: [String] {
        calendarStore.eventsByCalendar.flatMap { identifier, events in
            events.map { event in
                let dates = event.dates(in: Self.vienna).map(Self.day).joined(separator: "…")
                return "\(identifier) \(dates) \(event.title)\(event.isAllDay ? "" : " (timed)")"
            }
        }
        .sorted()
    }
}
