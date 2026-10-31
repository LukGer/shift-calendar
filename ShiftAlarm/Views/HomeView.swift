import EventKit
import SwiftData
import SwiftUI

/// Arms on launch, on every return to the foreground and whenever her calendar changes, and shows what the latest run
/// armed above a month of her Shifts.
struct HomeView: View {
    @Environment(Arming.self) private var arming
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @State private var isShowingSettings = false
    @State private var notificationPermission: NotificationPermission?
    @AppStorage("hasFinishedWalkthrough") private var hasFinishedWalkthrough = false
    /// EventKit only posts calendar changes while an event store is alive.
    @State private var watchedEventStore = EKEventStore()
    @State private var month = Date.now
    @State private var days: [GridDay] = []
    @State private var shiftTypes: [ShiftType] = []
    @State private var hasPlanningCalendar = false
    @State private var openDate: Date?
    @State private var opensSettingsAfterDaySheet = false
    private let calendarStore = EventKitCalendarStore()
    private let clock = SystemClock()

    var body: some View {
        NavigationStack {
            CalendarHome(
                result: arming.latestResult, notificationPermission: notificationPermission,
                month: month, days: days, calendar: clock.calendar, showMonth: showMonth,
                openDay: { openDate = $0.date }, toggleSkip: toggleSkip)
                .navigationTitle("Shifts")
                .toolbar {
                    Button("Settings", systemImage: "gearshape") { isShowingSettings = true }
                }
                .sheet(isPresented: $isShowingSettings, onDismiss: readMonth) {
                    SettingsView(notificationPermission: notificationPermission)
                }
                .sheet(isPresented: isShowingDaySheet, onDismiss: closeDaySheet) {
                    if let day = days.first(where: { $0.date == openDate }) {
                        DaySheet(
                            day: day, shiftTypes: shiftTypes, hasPlanningCalendar: hasPlanningCalendar,
                            plan: { shiftType in try await readMonth { try await planning.plan(shiftType, on: day.date) } },
                            takeOff: { shiftType in
                                try await readMonth { try await planning.takeOff(shiftType, on: day.date) }
                            },
                            toggleSkip: { toggleSkip(of: Shift(date: day.date, shiftType: $0.shiftType)) },
                            openSettings: {
                                opensSettingsAfterDaySheet = true
                                openDate = nil
                            })
                    }
                }
                .fullScreenCover(isPresented: isShowingWalkthrough, onDismiss: readMonth) {
                    Walkthrough()
                }
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            if phase == .active {
                armThenReadMonth()
                Task { notificationPermission = await UserNotificationsNotifier().permission() }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .EKEventStoreChanged, object: watchedEventStore)) { _ in
            armThenReadMonth()
        }
    }

    private var isShowingWalkthrough: Binding<Bool> {
        Binding { !hasFinishedWalkthrough } set: { hasFinishedWalkthrough = !$0 }
    }

    private var isShowingDaySheet: Binding<Bool> {
        Binding { openDate != nil } set: { if !$0 { openDate = nil } }
    }

    /// Reads again in case she edited a Shift Type from the sheet. Settings can only open once the sheet has gone.
    private func closeDaySheet() {
        readMonth()
        isShowingSettings = opensSettingsAfterDaySheet
        opensSettingsAfterDaySheet = false
    }

    private func toggleSkip(of shift: some SkippableShift) {
        try? context.toggleSkip(of: shift)
        armThenReadMonth()
    }

    private var planning: Planning {
        Planning(context: context, calendarStore: calendarStore, clock: clock, arming: arming)
    }

    private func readMonth(after change: () async throws -> Void) async throws {
        defer { readMonth() }
        try await change()
    }

    private func showMonth(_ offset: Int) {
        month = clock.calendar.date(byAdding: .month, value: offset, to: month)!
        readMonth()
    }

    /// Reads after the run, which prunes past Skips and drops those whose Shift Type changed.
    private func armThenReadMonth() {
        Task {
            await arming.run()
            readMonth()
        }
    }

    private func readMonth() {
        let chosenCalendars = (try? context.fetch(FetchDescriptor<ChosenCalendar>())) ?? []
        shiftTypes = (try? context.fetch(FetchDescriptor<ShiftType>(sortBy: [SortDescriptor(\.createdAt)]))) ?? []
        hasPlanningCalendar = chosenCalendars.planningCalendar(among: calendarStore.calendars()) != nil
        days = calendarStore.monthOfShifts(
            containing: month, in: chosenCalendars, of: shiftTypes,
            skips: (try? context.fetch(FetchDescriptor<Skip>())) ?? [],
            clock: clock)
    }
}

/// The arming banner, the next Shift, then the month grid.
struct CalendarHome: View {
    let result: ArmingResult?
    var notificationPermission: NotificationPermission?
    let month: Date
    let days: [GridDay]
    let calendar: Calendar
    let showMonth: (Int) -> Void
    let openDay: (GridDay) -> Void
    let toggleSkip: (WindowShift) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ArmingBanner(result: result, notificationPermission: notificationPermission)
                if case .armed(let shifts) = result {
                    NextShiftCard(shift: shifts.first, toggleSkip: toggleSkip)
                } else if result == nil {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                }
                MonthGrid(month: month, days: days, calendar: calendar, showMonth: showMonth, openDay: openDay)
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
    }
}

#Preview("Busy month") {
    NavigationStack {
        CalendarHome(
            result: .armed([.preview(inDays: 1, PreviewRoster.tagdienst, alarmTimes: ["05:00", "05:10", "05:20"])]),
            month: .now, days: PreviewRoster.busyMonth, calendar: .current,
            showMonth: { _ in }, openDay: { _ in }, toggleSkip: { _ in })
            .navigationTitle("Shifts")
    }
}

#Preview("Banner") {
    NavigationStack {
        CalendarHome(
            result: .failed, month: .now, days: PreviewRoster.busyMonth, calendar: .current,
            showMonth: { _ in }, openDay: { _ in }, toggleSkip: { _ in })
            .navigationTitle("Shifts")
    }
}
