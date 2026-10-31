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
    func plan(_ shiftType: ShiftType, on date: Date) async throws {
        let chosenCalendars = try context.fetch(FetchDescriptor<ChosenCalendar>())
        guard let planningCalendar = chosenCalendars.planningCalendar(among: calendarStore.calendars()) else {
            throw PlanningRefusal.noPlanningCalendar
        }
        guard date >= clock.calendar.startOfDay(for: clock.now) else { throw PlanningRefusal.pastDay }
        guard shift(of: shiftType, on: date, in: chosenCalendars) == nil else { throw PlanningRefusal.alreadyPlanned }
        try calendarStore.addAllDayEvent(
            titled: shiftType.shortcut, on: date, inCalendar: planningCalendar.identifier)
        await arming.run()
    }

    /// Deletes every event behind the Shift Type's Shift on `date`, which also removes duplicates.
    func takeOff(_ shiftType: ShiftType, on date: Date) async throws {
        let chosenCalendars = try context.fetch(FetchDescriptor<ChosenCalendar>())
        guard let shift = shift(of: shiftType, on: date, in: chosenCalendars) else { return }
        guard !shift.isLocked else { throw PlanningRefusal.locked }
        for event in shift.events {
            try calendarStore.deleteEvent(identifier: event.identifier)
        }
        await arming.run()
    }

    private func shift(
        of shiftType: ShiftType, on date: Date, in chosenCalendars: [ChosenCalendar]
    ) -> ShiftInCalendar? {
        let nextDay = clock.calendar.date(byAdding: .day, value: 1, to: date)!
        return calendarStore.shiftsInCalendar(
            in: chosenCalendars, of: [shiftType], from: date, to: nextDay, clock: clock
        ).first { $0.shift.date == date }
    }
}

/// Why Planning left her calendar alone.
enum PlanningRefusal: Error {
    case noPlanningCalendar, pastDay, alreadyPlanned, locked
}
