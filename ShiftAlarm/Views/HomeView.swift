import SwiftUI

/// Arms on launch and on every return to the foreground, and shows what the latest run armed.
struct HomeView: View {
    @Environment(Arming.self) private var arming
    @Environment(\.scenePhase) private var scenePhase
    @State private var isShowingSettings = false

    var body: some View {
        NavigationStack {
            NextShiftView(result: arming.latestResult)
                .navigationTitle("Next Shift")
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

/// The next Shift in a hero card, then a compact row for every later Shift in the Arming Window.
struct NextShiftView: View {
    let result: ArmingResult?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                if result == .failed {
                    ArmingBanner(
                        title: "Alarms couldn't be armed",
                        text: "Shift Alarm tries again the next time you open it."
                    )
                }
                if case .armed(let shifts) = result {
                    if let next = shifts.first {
                        NextShiftCard(shift: next)
                        LaterThisWeek(shifts: shifts.dropFirst())
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

/// Tells her why the latest run didn't arm.
struct ArmingBanner: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(title, systemImage: "exclamationmark.triangle")
                .font(.headline)
            Text(text)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.tint.opacity(0.1), in: .rect(cornerRadius: 20))
    }
}

private struct NextShiftCard: View {
    let shift: ArmedShift

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
            } else {
                Text(shift.alarmTimes.summary)
                    .font(.title2)
            }
            if shift.alarmTimes.count > 1 {
                Text("then " + shift.alarmTimes.dropFirst().summary)
                    .monospacedDigit()
            }
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
                        Text(shift.alarmTimes.summary)
                            .font(.subheadline.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                }
            }
            .background(.background, in: .rect(cornerRadius: 16))
        }
    }
}

#Preview("Shifts") {
    NavigationStack {
        NextShiftView(result: .armed([
            .preview(inDays: 1, "Tagdienst", .orange, alarmTimes: ["05:00", "05:10", "05:20"]),
            .preview(inDays: 2, "Nachtdienst", .indigo, alarmTimes: ["16:30", "16:45"]),
            .preview(inDays: 3, "Nachtdienst", .indigo, alarmTimes: ["16:30", "16:45"]),
            .preview(inDays: 5, "Spätdienst", .teal, alarmTimes: []),
        ]))
        .navigationTitle("Next Shift")
    }
}

#Preview("Next Shift rings nothing") {
    NavigationStack {
        NextShiftView(result: .armed([.preview(inDays: 0, "Spätdienst", .teal, alarmTimes: [])]))
            .navigationTitle("Next Shift")
    }
}

#Preview("No Shifts") {
    NavigationStack {
        NextShiftView(result: .armed([]))
            .navigationTitle("Next Shift")
    }
}

#Preview("Banner") {
    NavigationStack {
        NextShiftView(result: .failed)
            .navigationTitle("Next Shift")
    }
}

private extension ArmedShift {
    static func preview(inDays days: Int, _ name: String, _ color: Color, alarmTimes: [String]) -> ArmedShift {
        let calendar = Calendar.current
        return ArmedShift(
            date: calendar.date(byAdding: .day, value: days, to: calendar.startOfDay(for: .now))!,
            shiftTypeID: UUID(),
            name: name,
            color: color,
            alarmTimes: alarmTimes.map { text in
                let parts = text.split(separator: ":").compactMap { Int($0) }
                return AlarmTime(hour: parts[0], minute: parts[1])
            }
        )
    }
}
