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
        guard let planningCalendar = chosenCalendars.planningCalendar(among: calendarStore.calendars()) else {
            throw PlanningRefusal.noPlanningCalendar
        }
        try calendarStore.addAllDayEvent(
            titled: shiftType.shortcut, on: date, inCalendar: planningCalendar.identifier)
        await arming.run()
    }
}

/// Why Planning left her calendar alone.
enum PlanningRefusal: Error {
    case noPlanningCalendar
}
