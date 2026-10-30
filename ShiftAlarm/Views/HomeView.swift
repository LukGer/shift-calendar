import SwiftData
import SwiftUI

/// Arms on launch and on every return to the foreground, and lists what the latest run armed.
struct HomeView: View {
    @Environment(Arming.self) private var arming
    @Environment(\.scenePhase) private var scenePhase
    @Query private var armingRecords: [ArmingRecord]
    @State private var isShowingSettings = false

    var body: some View {
        NavigationStack {
            ArmedShiftsList(result: arming.latestResult)
                .safeAreaInset(edge: .top) {
                    ArmingBanner(outcome: armingRecords.first?.latestOutcome)
                        .padding(.horizontal)
                }
                .navigationTitle("Shifts")
                .toolbar {
                    Button("Settings", systemImage: "gearshape") { isShowingSettings = true }
                }
                .sheet(isPresented: $isShowingSettings) {
                    SettingsView()
                }
        }
        .onChange(of: scenePhase, initial: true) { _, phase in
            if phase == .active {
                Task { await arming.run() }
            }
        }
    }
}

struct ArmedShiftsList: View {
    let result: ArmingResult?

    var body: some View {
        switch result {
        case .armed(let shifts) where !shifts.isEmpty:
            List(shifts) { shift in
                LabeledContent {
                    Text(shift.alarmTimes.summary)
                        .monospacedDigit()
                } label: {
                    Label {
                        Text(shift.name)
                        Text(shift.date, format: .dateTime.weekday(.wide).day().month())
                    } icon: {
                        Circle()
                            .fill(shift.color)
                            .frame(width: 10)
                    }
                }
            }
        case .armed:
            ContentUnavailableView(
                "No Shifts this week",
                systemImage: "calendar",
                description: Text("Days without a Shift ring nothing.")
            )
        case .skipped, .failed:
            ContentUnavailableView(
                "Alarms weren't updated",
                systemImage: "exclamationmark.triangle",
                description: Text("Alarms already armed still ring.")
            )
        case nil:
            ProgressView()
        }
    }
}

#Preview("Armed") {
    NavigationStack {
        ArmedShiftsList(result: .armed([
            ArmedShift(
                date: .now.addingTimeInterval(86_400), shiftTypeID: UUID(), name: "Tagdienst", color: .orange,
                alarmTimes: [AlarmTime(hour: 5, minute: 0), AlarmTime(hour: 5, minute: 10)]),
            ArmedShift(
                date: .now.addingTimeInterval(2 * 86_400), shiftTypeID: UUID(), name: "Spät", color: .teal,
                alarmTimes: []),
        ]))
        .navigationTitle("Shifts")
    }
}

#Preview("No Shifts") {
    ArmedShiftsList(result: .armed([]))
}

#Preview("Failed") {
    ArmedShiftsList(result: .failed)
}
