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
    private let calendarReader = EventKitReader()
    private let clock = SystemClock()

    var body: some View {
        NavigationStack {
            CalendarHome(
                result: arming.latestResult, notificationPermission: notificationPermission,
                month: month, days: days, calendar: clock.calendar, showMonth: showMonth, toggleSkip: toggleSkip)
                .navigationTitle("Shifts")
                .toolbar {
                    Button("Settings", systemImage: "gearshape") { isShowingSettings = true }
                }
                .sheet(isPresented: $isShowingSettings, onDismiss: readMonth) {
                    SettingsView(notificationPermission: notificationPermission)
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

    private func toggleSkip(of shift: WindowShift) {
        try? context.toggleSkip(of: shift)
        armThenReadMonth()
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
        days = calendarReader.monthOfShifts(
            containing: month,
            in: (try? context.fetch(FetchDescriptor<ChosenCalendar>())) ?? [],
            of: (try? context.fetch(FetchDescriptor<ShiftType>())) ?? [],
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
                MonthGrid(month: month, days: days, calendar: calendar, showMonth: showMonth)
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
            month: .now, days: PreviewRoster(clock: SystemClock()).busyMonth, calendar: .current,
            showMonth: { _ in }, toggleSkip: { _ in })
            .navigationTitle("Shifts")
    }
}

#Preview("Banner") {
    NavigationStack {
        CalendarHome(
            result: .failed, month: .now, days: PreviewRoster(clock: SystemClock()).busyMonth, calendar: .current,
            showMonth: { _ in }, toggleSkip: { _ in })
            .navigationTitle("Shifts")
    }
}
