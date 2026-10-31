import Foundation

extension CalendarStore {
    /// The all-day titles in her roster, from today to three months ahead, that are not a Shift Type yet:
    /// what Settings and the walkthrough offer to make into Shift Types.
    func unmatchedTitles(
        in chosenCalendars: [ChosenCalendar], of shiftTypes: [ShiftType], now: Date, calendar: Calendar
    ) -> [String] {
        let today = calendar.startOfDay(for: now)
        let threeMonthsAhead = calendar.date(byAdding: .month, value: 3, to: today)!
        let roster = events(inCalendars: chosenCalendars.map(\.identifier), from: today, to: threeMonthsAhead)
        return Shift.unmatchedTitles(in: roster, of: shiftTypes)
    }
}
