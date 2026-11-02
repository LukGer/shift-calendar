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
    @State private var month = Calendar.current.dateInterval(of: .month, for: .now)!.start
    @State private var daysByMonth: [Date: [GridDay]] = [:]
    @State private var shiftTypes: [ShiftType] = []
    @State private var hasPlanningCalendar = false
    @State private var refusal: String?
    private let calendarStore = EventKitCalendarStore()
    private let clock = SystemClock()

    var body: some View {
        NavigationStack {
            CalendarHome(
                result: arming.latestResult, notificationPermission: notificationPermission,
                month: $month, daysByMonth: daysByMonth, calendar: clock.calendar, toggleSkip: toggleSkip
            ) { day in
                DayMenu(
                    day: day, shiftTypes: shiftTypes, hasPlanningCalendar: hasPlanningCalendar,
                    plan: { shiftType in change { try await planning.plan(shiftType, on: day.date) } },
                    takeOff: { shiftType in change { try await planning.takeOff(shiftType, on: day.date) } },
                    toggleSkip: { toggleSkip(of: Shift(date: day.date, shiftType: $0.shiftType)) },
                    openSettings: { isShowingSettings = true })
            }
            .navigationTitle("Shifts")
            .toolbar {
                Button("Settings", systemImage: "gearshape") { isShowingSettings = true }
            }
            .sheet(isPresented: $isShowingSettings, onDismiss: readMonths) {
                SettingsView(notificationPermission: notificationPermission)
            }
            .alert(refusal ?? "", isPresented: isShowingRefusal) {}
            .fullScreenCover(isPresented: isShowingWalkthrough, onDismiss: readMonths) {
                Walkthrough()
            }
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            if phase == .active {
                armThenReadMonths()
                Task { notificationPermission = await UserNotificationsNotifier().permission() }
            }
        }
        .onChange(of: month) { readMonths() }
        .onReceive(NotificationCenter.default.publisher(for: .EKEventStoreChanged, object: watchedEventStore)) { _ in
            armThenReadMonths()
        }
    }

    private var isShowingWalkthrough: Binding<Bool> {
        Binding { !hasFinishedWalkthrough } set: { hasFinishedWalkthrough = !$0 }
    }

    private var isShowingRefusal: Binding<Bool> {
        Binding { refusal != nil } set: { if !$0 { refusal = nil } }
    }

    /// Shows the Skip straight away; the run then cancels or re-arms its alarms.
    private func toggleSkip(of shift: some SkippableShift) {
        try? context.toggleSkip(of: shift)
        readMonths()
        armThenReadMonths()
    }

    private var planning: Planning {
        Planning(context: context, calendarStore: calendarStore, clock: clock, arming: arming)
    }

    /// Plans or takes off a Shift, then shows the month as it now is, or why her calendar was left alone.
    private func change(_ planning: @escaping () async throws -> Void) {
        Task {
            defer { readMonths() }
            do {
                try await planning()
            } catch {
                refusal = (error as? PlanningRefusal)?.explanation ?? String(localized: "Couldn't change your calendar.")
            }
        }
    }

    /// Reads after the run, which prunes past Skips and drops those whose Shift Type changed.
    private func armThenReadMonths() {
        Task {
            await arming.run()
            readMonths()
        }
    }

    /// Reads the month on screen and its neighbours, so a swipe always lands on a filled month.
    private func readMonths() {
        let chosenCalendars = (try? context.fetch(FetchDescriptor<ChosenCalendar>())) ?? []
        let skips = (try? context.fetch(FetchDescriptor<Skip>())) ?? []
        shiftTypes = (try? context.fetch(FetchDescriptor<ShiftType>(sortBy: [SortDescriptor(\.createdAt)]))) ?? []
        hasPlanningCalendar = chosenCalendars.planningCalendar(among: calendarStore.calendars()) != nil
        daysByMonth = Dictionary(uniqueKeysWithValues: (-1...1).map { offset in
            let page = clock.calendar.date(byAdding: .month, value: offset, to: month)!
            return (page, calendarStore.monthOfShifts(
                containing: page, in: chosenCalendars, of: shiftTypes, skips: skips, clock: clock))
        })
    }
}

/// The arming banner, the next Shift, then the month grid.
struct CalendarHome<DayMenuContent: View>: View {
    let result: ArmingResult?
    var notificationPermission: NotificationPermission?
    @Binding var month: Date
    let daysByMonth: [Date: [GridDay]]
    let calendar: Calendar
    let toggleSkip: (WindowShift) -> Void
    @ViewBuilder let dayMenu: (GridDay) -> DayMenuContent

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ArmingBanner(result: result, notificationPermission: notificationPermission)
                    .padding(.horizontal)
                    .transition(.move(edge: .top).combined(with: .opacity))
                if case .armed(let shifts) = result {
                    NextShiftCard(shift: shifts.first, toggleSkip: toggleSkip)
                        .padding(.horizontal)
                        .transition(.scale(scale: 0.95).combined(with: .opacity))
                } else if result == nil {
                    ProgressView()
                        .frame(maxWidth: .infinity)
                }
                MonthGrid(month: $month, daysByMonth: daysByMonth, calendar: calendar, dayMenu: dayMenu)
            }
            .padding(.vertical)
            .animation(.smooth, value: result)
        }
        .background(Color(.systemGroupedBackground))
    }
}

#Preview("Busy month") {
    @Previewable @State var month = Calendar.current.dateInterval(of: .month, for: .now)!.start
    NavigationStack {
        CalendarHome(
            result: .armed([.preview(inDays: 1, PreviewCalendarStore.tagdienst, alarmTimes: ["05:00", "05:10", "05:20"])]),
            month: $month, daysByMonth: [month: PreviewCalendarStore.busyMonth], calendar: .current,
            toggleSkip: { _ in }
        ) { day in
            Text(day.title)
        }
        .navigationTitle("Shifts")
    }
}

#Preview("Banner") {
    @Previewable @State var month = Calendar.current.dateInterval(of: .month, for: .now)!.start
    NavigationStack {
        CalendarHome(
            result: .failed, month: $month, daysByMonth: [month: PreviewCalendarStore.busyMonth], calendar: .current,
            toggleSkip: { _ in }
        ) { day in
            Text(day.title)
        }
        .navigationTitle("Shifts")
    }
}
