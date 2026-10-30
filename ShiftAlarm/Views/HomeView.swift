import EventKit
import SwiftData
import SwiftUI

/// Arms on launch, on every return to the foreground and whenever her calendar changes, and shows what the latest run armed.
struct HomeView: View {
    @Environment(Arming.self) private var arming
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @State private var isShowingSettings = false
    @State private var notificationsAllowed = true
    @AppStorage("hasFinishedWalkthrough") private var hasFinishedWalkthrough = false
    /// EventKit only posts calendar changes while an event store is alive.
    @State private var watchedEventStore = EKEventStore()

    var body: some View {
        NavigationStack {
            NextShiftView(
                result: arming.latestResult, notificationsAllowed: notificationsAllowed, toggleSkip: toggleSkip)
                .navigationTitle("Next Shift")
                .toolbar {
                    Button("Settings", systemImage: "gearshape") { isShowingSettings = true }
                }
                .sheet(isPresented: $isShowingSettings) {
                    SettingsView()
                }
                .fullScreenCover(isPresented: isShowingWalkthrough) {
                    Walkthrough()
                }
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            if phase == .active {
                Task { await arming.run() }
                Task { notificationsAllowed = await UserNotificationsNotifier().isAuthorized() }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .EKEventStoreChanged, object: watchedEventStore)) { _ in
            Task { await arming.run() }
        }
    }

    /// Shown on every launch until she finishes it.
    private var isShowingWalkthrough: Binding<Bool> {
        Binding { !hasFinishedWalkthrough } set: { hasFinishedWalkthrough = !$0 }
    }

    private func toggleSkip(of shift: ArmedShift) {
        try? context.toggleSkip(of: shift)
        Task { await arming.run() }
    }
}

/// The next Shift in a hero card, then a compact row for every later Shift in the Arming Window.
struct NextShiftView: View {
    let result: ArmingResult?
    var notificationsAllowed = true
    let toggleSkip: (ArmedShift) -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                ArmingBanner(outcome: result?.outcome, notificationsAllowed: notificationsAllowed)
                if case .armed(let shifts) = result {
                    if let next = shifts.first {
                        NextShiftCard(shift: next, toggleSkip: toggleSkip)
                        LaterThisWeek(shifts: shifts.dropFirst(), toggleSkip: toggleSkip)
                        Text("Days without a Shift ring nothing.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    } else {
                        ContentUnavailableView(
                            "No Shifts this week",
                            systemImage: "calendar",
                            description: Text("Days without a Shift ring nothing.")
                        )
                    }
                }
            }
            .padding()
        }
        .background(Color(.systemGroupedBackground))
        .overlay {
            if result == nil {
                ProgressView()
            }
        }
    }
}

private struct NextShiftCard: View {
    let shift: ArmedShift
    let toggleSkip: (ArmedShift) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(dayTitle.uppercased())
                .font(.caption.bold())
                .opacity(0.8)
            Text(shift.name)
                .font(.largeTitle.bold())
            if let first = shift.alarmTimes.first {
                Text(first.text)
                    .font(.system(size: 64, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .strikethrough(shift.isSkipped)
            } else {
                Text(shift.alarmTimes.summary)
                    .font(.title2)
            }
            if shift.isSkipped {
                Text("Skipped")
            } else if shift.alarmTimes.count > 1 {
                Text("then " + shift.alarmTimes.dropFirst().summary)
                    .monospacedDigit()
            }
            SkipButton(shift: shift, toggleSkip: toggleSkip)
                .buttonStyle(.bordered)
                .tint(.white)
                .padding(.top, 8)
        }
        .foregroundStyle(.white)
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(shift.color.gradient, in: .rect(cornerRadius: 24))
    }

    private var dayTitle: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(shift.date) { return "Today" }
        if calendar.isDateInTomorrow(shift.date) { return "Tomorrow" }
        return shift.date.formatted(.dateTime.weekday(.wide).day().month(.abbreviated))
    }
}

private struct LaterThisWeek: View {
    let shifts: ArraySlice<ArmedShift>
    let toggleSkip: (ArmedShift) -> Void

    var body: some View {
        if !shifts.isEmpty {
            Text("Later this week")
                .font(.headline)
                .padding(.top)
            VStack(spacing: 0) {
                ForEach(shifts) { shift in
                    if shift != shifts.first {
                        Divider()
                    }
                    HStack {
                        Text(shift.date, format: .dateTime.weekday(.abbreviated).day())
                            .frame(width: 64, alignment: .leading)
                            .foregroundStyle(.secondary)
                        Circle()
                            .fill(shift.color)
                            .frame(width: 10)
                        Text(shift.name)
                        Spacer()
                        Text(shift.isSkipped ? "Skipped" : shift.alarmTimes.summary)
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(shift.isSkipped ? .orange : .secondary)
                        Menu {
                            SkipButton(shift: shift, toggleSkip: toggleSkip)
                        } label: {
                            Label("Options", systemImage: "ellipsis.circle")
                                .labelStyle(.iconOnly)
                        }
                    }
                    .padding()
                }
            }
            .background(.background, in: .rect(cornerRadius: 16))
        }
    }
}

private struct SkipButton: View {
    let shift: ArmedShift
    let toggleSkip: (ArmedShift) -> Void

    var body: some View {
        Button(shift.isSkipped ? "Ring for this Shift" : "Skip this Shift", systemImage: "moon.zzz") {
            toggleSkip(shift)
        }
    }
}

#Preview("Shifts") {
    NavigationStack {
        NextShiftView(result: .armed([
            .preview(inDays: 1, "Tagdienst", .orange, alarmTimes: ["05:00", "05:10", "05:20"]),
            .preview(inDays: 2, "Nachtdienst", .indigo, alarmTimes: ["16:30", "16:45"]),
            .preview(inDays: 3, "Nachtdienst", .indigo, alarmTimes: ["16:30", "16:45"], isSkipped: true),
            .preview(inDays: 5, "Spätdienst", .teal, alarmTimes: []),
        ]), toggleSkip: { _ in })
        .navigationTitle("Next Shift")
    }
}

#Preview("Next Shift skipped") {
    NavigationStack {
        NextShiftView(
            result: .armed([.preview(inDays: 1, "Tagdienst", .orange, alarmTimes: ["05:00", "05:10"], isSkipped: true)]),
            toggleSkip: { _ in }
        )
        .navigationTitle("Next Shift")
    }
}

#Preview("Next Shift rings nothing") {
    NavigationStack {
        NextShiftView(result: .armed([.preview(inDays: 0, "Spätdienst", .teal, alarmTimes: [])]), toggleSkip: { _ in })
            .navigationTitle("Next Shift")
    }
}

#Preview("No Shifts") {
    NavigationStack {
        NextShiftView(result: .armed([]), toggleSkip: { _ in })
            .navigationTitle("Next Shift")
    }
}

#Preview("Banner") {
    NavigationStack {
        NextShiftView(result: .failed, toggleSkip: { _ in })
            .navigationTitle("Next Shift")
    }
}

private extension ArmedShift {
    static func preview(
        inDays days: Int, _ name: String, _ color: Color, alarmTimes: [String], isSkipped: Bool = false
    ) -> ArmedShift {
        let calendar = Calendar.current
        return ArmedShift(
            date: calendar.date(byAdding: .day, value: days, to: calendar.startOfDay(for: .now))!,
            shiftTypeID: UUID(),
            name: name,
            color: color,
            alarmTimes: alarmTimes.map { text in
                let parts = text.split(separator: ":").compactMap { Int($0) }
                return AlarmTime(hour: parts[0], minute: parts[1])
            },
            isSkipped: isSkipped
        )
    }
}
