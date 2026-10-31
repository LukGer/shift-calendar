import Foundation
import SwiftData

/// Putting a Shift on a date or taking it off, by writing or deleting its all-day event in her calendar.
/// Each change arms straight away.
struct Planning {
    let context: ModelContext
    let calendarStore: CalendarStore
    let clock: WallClock
    let arming: Arming

    /// Writes one all-day event titled with the Shift Type's Shortcut on `date` into the Planning Calendar.
    func toggleOn(_ shiftType: ShiftType, on date: Date) async throws {
        let chosenCalendars = try context.fetch(FetchDescriptor<ChosenCalendar>())
        try calendarStore.addAllDayEvent(
            titled: shiftType.shortcut, on: date, inCalendar: chosenCalendars[0].identifier)
        await arming.run()
    }
}
