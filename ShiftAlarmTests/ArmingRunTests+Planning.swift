import Foundation
import SwiftData
import Testing
@testable import ShiftAlarm

/// Planning: putting a Shift on a date or taking it off from the day sheet, then arming.
/// "Now" is 2031-03-02 20:00, so the Arming Window covers 2031-03-02 to 2031-03-09.
extension ArmingRunTests {
    @Test(arguments: [
        ("td", "2031-03-03", ["2031-03-03 05:00 Tagdienst"]),
        ("td", "2031-03-02", []),
        ("nd", "2031-03-09", ["2031-03-09 18:30 Nachtdienst"]),
        ("hrn", "2031-03-20", []),
        ("e6", "2031-03-03", []),
    ])
    func planningAShiftTypeWritesItsShortcutIntoThePlanningCalendarAndArmsIt(
        shortcut: String, date: String, expectedAlarms: [String]
    ) async throws {
        addHerShiftTypes()

        try await plan(shortcut, on: date)

        #expect(calendarHolds == ["dienste \(date) \(shortcut)"])
        #expect(armedAlarms == expectedAlarms)
    }

    /// Her calendars in Settings order: Dienste, Privat and Arbeit she can edit, Feiertage she can't.
    enum ChosenCalendars: CaseIterable {
        case oneEditable, oneEditableAndOneSheCantEdit, severalNoneMarked, severalWithOneMarked
        case severalWithTheMarkedOneGone, severalWithTheMarkedOneNowReadOnly, severalWithTheMarkedOneFoundAgain
        case onlyOneSheCantEdit, none
    }

    @Test(arguments: [
        (ChosenCalendars.oneEditable, "dienste"),
        (.oneEditableAndOneSheCantEdit, "dienste"),
        (.severalNoneMarked, "dienste"),
        (.severalWithOneMarked, "arbeit"),
        (.severalWithTheMarkedOneGone, "dienste"),
        (.severalWithTheMarkedOneNowReadOnly, "dienste"),
        (.severalWithTheMarkedOneFoundAgain, "arbeit-2"),
    ])
    func newShiftsGoIntoTheMarkedEditableChosenCalendarOrElseTheFirstEditableOne(
        chosen: ChosenCalendars, expected: String
    ) async throws {
        addHerShiftTypes()
        try choose(chosen)

        try await plan("td", on: "2031-03-03")

        #expect(calendarHolds == ["\(expected) 2031-03-03 td"])
    }

    @Test(arguments: [
        (ChosenCalendars.onlyOneSheCantEdit, "2031-03-03", [], PlanningRefusal.noPlanningCalendar),
        (.none, "2031-03-03", [], .noPlanningCalendar),
        (.oneEditable, "2031-03-01", [], .pastDay),
        (.oneEditable, "2031-02-15", [], .pastDay),
        (.oneEditable, "2031-03-03", [("td", "2031-03-03", "2031-03-03")], .alreadyPlanned),
        (.oneEditable, "2031-03-03", [(" TD ", "2031-03-03", "2031-03-03")], .alreadyPlanned),
        (.oneEditable, "2031-03-03", [("td", "2031-03-02", "2031-03-04")], .alreadyPlanned),
    ])
    func planningRefusesWithoutAPlanningCalendarOnAPastDayOrWhenTheShiftIsAlreadyThere(
        chosen: ChosenCalendars, date: String, alreadyThere: [(String, String, String)], refusal: PlanningRefusal
    ) async throws {
        addHerShiftTypes()
        try choose(chosen)
        for (title, first, last) in alreadyThere {
            roster(allDay(title, from: first, through: last))
        }
        let before = calendarHolds

        await #expect(throws: refusal) { try await plan("td", on: date) }

        #expect(calendarHolds == before)
    }

    /// Events as (title, date, calendar), with Arbeit, Privat and Dienste chosen.
    nonisolated static let rostersToTakeTagdienstOffOn0303: [([(String, String, String)], [String], [String])] = [
        ([("td", "2031-03-03", "dienste")], [], []),
        ([("td", "2031-03-03", "dienste"), (" TD ", "2031-03-03", "dienste")], [], []),
        ([("td", "2031-03-03", "dienste"), ("td", "2031-03-03", "arbeit")], [], []),
        (
            [("td", "2031-03-03", "dienste"), ("hrn", "2031-03-03", "dienste")],
            ["dienste 2031-03-03 hrn"], ["2031-03-03 06:15 Hausrunde"]
        ),
        (
            [("td", "2031-03-03", "dienste"), ("td", "2031-03-04", "dienste")],
            ["dienste 2031-03-04 td"], ["2031-03-04 05:00 Tagdienst"]
        ),
        (
            [("td", "2031-03-03", "privat"), ("U", "2031-03-03", "privat"), ("frei", "2031-03-03", "dienste")],
            ["dienste 2031-03-03 frei", "privat 2031-03-03 U"], []
        ),
    ]

    @Test(arguments: rostersToTakeTagdienstOffOn0303)
    func takingAShiftOffDeletesEveryMatchingEventOnThatDateAndCancelsItsAlarms(
        events: [(String, String, String)], expectedEvents: [String], expectedAlarms: [String]
    ) async throws {
        addHerShiftTypes()
        try choose(.severalNoneMarked)
        for (title, date, calendar) in events {
            roster(allDay(title, on: date), in: calendar)
        }
        await arming.run()

        try await takeOff("td", on: "2031-03-03")

        #expect(calendarHolds == expectedEvents)
        #expect(armedAlarms == expectedAlarms)
    }

    @Test(arguments: [
        EventsBehindAShift.aPastEvent, .aMultiDayEvent, .aRecurringEvent, .anEventInACalendarSheCantEdit,
        .aSingleDayEventAndARecurringOne, .aSingleDayEventAndOneInACalendarSheCantEdit,
    ])
    func takingALockedShiftOffRefusesAndLeavesHerCalendarAlone(events: EventsBehindAShift) async throws {
        addHerShiftTypes()
        let date = try roster(events)
        let before = calendarHolds

        await #expect(throws: PlanningRefusal.locked) { try await takeOff("td", on: date) }

        #expect(calendarHolds == before)
    }

    /// Changes on 2031-03-03 over a Tagdienst there: "+nd" plans Nachtdienst, "-td" takes Tagdienst off.
    @Test(arguments: [
        (["-td", "+nd"], ["dienste 2031-03-03 nd"], ["2031-03-03 18:30 Nachtdienst"]),
        (["+hrn"], ["dienste 2031-03-03 hrn", "dienste 2031-03-03 td"],
         ["2031-03-03 05:00 Tagdienst", "2031-03-03 06:15 Hausrunde"]),
        (["-td", "+td"], ["dienste 2031-03-03 td"], ["2031-03-03 05:00 Tagdienst"]),
        (["-td"], [], []),
    ])
    func changingADaysShiftOrPlanningASecondOneArmsWhatIsThereAfterwards(
        changes: [String], expectedEvents: [String], expectedAlarms: [String]
    ) async throws {
        addHerShiftTypes()
        roster(allDay("td", on: "2031-03-03"))
        await arming.run()

        for change in changes {
            let shortcut = String(change.dropFirst())
            if change.hasPrefix("+") {
                try await plan(shortcut, on: "2031-03-03")
            } else {
                try await takeOff(shortcut, on: "2031-03-03")
            }
        }

        #expect(calendarHolds == expectedEvents)
        #expect(armedAlarms == expectedAlarms)
    }

    @Test(arguments: ["2031-03-03", "2031-03-20"])
    func aSkipSurvivesTakingTheShiftOffAndPlanningItAgain(date: String) async throws {
        addHerShiftTypes()
        roster(allDay("td", on: date))
        try toggleSkip("td", on: date)
        await arming.run()

        try await takeOff("td", on: date)
        try await plan("td", on: date)

        #expect(armedAlarms == [])
        #expect(try shifts(in: "2031-03", where: \.isSkipped) == ["\(date) td"])
    }

    // MARK: - Fixtures

    func takeOff(_ shortcut: String, on date: String) async throws {
        try await planning.takeOff(try shiftType(shortcut), on: Self.instant("\(date) 00:00"))
    }

    func choose(_ chosen: ChosenCalendars) throws {
        calendarStore.deviceCalendars = [
            DeviceCalendar(identifier: "dienste", title: "Dienste", sourceIdentifier: "icloud", isEditable: true),
            DeviceCalendar(identifier: "privat", title: "Privat", sourceIdentifier: "icloud", isEditable: true),
            DeviceCalendar(identifier: "arbeit", title: "Arbeit", sourceIdentifier: "google", isEditable: true),
            DeviceCalendar(identifier: "feiertage", title: "Feiertage", sourceIdentifier: "icloud", isEditable: false),
        ]
        switch chosen {
        case .oneEditable:
            try choose(["dienste"])
        case .oneEditableAndOneSheCantEdit:
            try choose(["feiertage", "dienste"])
        case .severalNoneMarked:
            try choose(["arbeit", "privat", "dienste"])
        case .severalWithOneMarked:
            try choose(["dienste", "privat", "arbeit"], marking: "arbeit")
        case .severalWithTheMarkedOneGone:
            try choose(["dienste", "privat", "arbeit"], marking: "arbeit")
            calendarStore.deviceCalendars.remove(at: 2)
        case .severalWithTheMarkedOneNowReadOnly:
            try choose(["dienste", "privat", "arbeit"], marking: "arbeit")
            calendarStore.deviceCalendars[2] = DeviceCalendar(
                identifier: "arbeit", title: "Arbeit", sourceIdentifier: "google", isEditable: false)
        case .severalWithTheMarkedOneFoundAgain:
            try choose(["dienste", "privat", "arbeit"], marking: "arbeit")
            calendarStore.deviceCalendars[2] = DeviceCalendar(
                identifier: "arbeit-2", title: "Arbeit", sourceIdentifier: "google", isEditable: true)
        case .onlyOneSheCantEdit:
            try choose(["feiertage"])
        case .none:
            try choose([])
        }
    }

    /// Chooses these of the device's calendars in place of Dienste, the way Settings does.
    func choose(_ identifiers: [String], marking marked: String? = nil) throws {
        let context = container.mainContext
        try context.fetch(FetchDescriptor<ChosenCalendar>()).forEach(context.delete)
        for identifier in identifiers {
            let calendar = try #require(calendarStore.deviceCalendars.first { $0.identifier == identifier })
            context.insert(ChosenCalendar(
                identifier: calendar.identifier, title: calendar.title, sourceIdentifier: calendar.sourceIdentifier))
        }
        let chosenCalendars = try context.fetch(FetchDescriptor<ChosenCalendar>())
        if let marked {
            chosenCalendars.markAsPlanningCalendar(try #require(chosenCalendars.first { $0.identifier == marked }))
        }
        try context.save()
    }

    var planning: Planning {
        Planning(context: container.mainContext, calendarStore: calendarStore, clock: clock, arming: arming)
    }

    func plan(_ shortcut: String, on date: String) async throws {
        try await planning.plan(try shiftType(shortcut), on: Self.instant("\(date) 00:00"))
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
