import SwiftUI

/// A day of the month grid: her Shift Types to tick, then Skip and Edit Shift Type for each Shift on it.
/// Past days leave only Edit Shift Type; without a Planning Calendar her Shift Types are read-only.
struct DaySheet: View {
    let day: GridDay
    let shiftTypes: [ShiftType]
    let hasPlanningCalendar: Bool
    /// Ticks the Shift Type on the day when true, unticks it when false.
    let toggle: (ShiftType, Bool) async throws -> Void
    let toggleSkip: (GridShift) -> Void
    let openSettings: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var refusal: String?

    var body: some View {
        NavigationStack {
            List {
                if shiftTypes.isEmpty {
                    SettingsNotice(
                        title: "No Shift Types yet", message: "Set up your Shift Types in Settings to plan Shifts.",
                        openSettings: openSettings)
                } else {
                    shiftTypeToggles
                    ForEach(day.shifts, id: \.shiftType.id, content: shiftActions)
                    if !hasPlanningCalendar && !day.isPast {
                        SettingsNotice(
                            title: "Read-only", message: "Choose a calendar you can edit in Settings.",
                            openSettings: openSettings)
                    }
                }
            }
            .navigationTitle(day.date.formatted(.dateTime.weekday(.wide).day().month(.wide)))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private var shiftTypeToggles: some View {
        Section {
            ForEach(shiftTypes) { shiftType in
                let shift = day.shifts.first { $0.shiftType.id == shiftType.id }
                Toggle(isOn: isTicked(shiftType, shift: shift)) {
                    HStack(spacing: 12) {
                        Circle()
                            .fill(shiftType.color.gradient)
                            .frame(width: 12, height: 12)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(shiftType.name)
                            if shift?.isLocked == true && !day.isPast {
                                Text("Edit in Calendar")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Text(shiftType.shortcut)
                            .monospaced()
                            .foregroundStyle(.secondary)
                    }
                }
                .tint(shiftType.color)
                .disabled(day.isPast || !hasPlanningCalendar || shift?.isLocked == true)
            }
        } header: {
            Text("Shifts")
        } footer: {
            if let refusal {
                Text(refusal)
                    .foregroundStyle(.red)
            } else if day.isPast {
                Text("Past days can't be changed.")
            }
        }
    }

    private func shiftActions(for shift: GridShift) -> some View {
        Section(shift.shiftType.name) {
            if !day.isPast {
                Button(
                    shift.isSkipped ? "Ring for this Shift" : "Skip this Shift",
                    systemImage: shift.isSkipped ? "bell" : "moon.zzz"
                ) {
                    toggleSkip(shift)
                }
            }
            NavigationLink {
                ShiftTypeEditor(shiftType: shift.shiftType)
            } label: {
                Label("Edit Shift Type", systemImage: "slider.horizontal.3")
            }
        }
    }

    private func isTicked(_ shiftType: ShiftType, shift: GridShift?) -> Binding<Bool> {
        Binding {
            shift != nil
        } set: { isOn in
            Task {
                do {
                    refusal = nil
                    try await toggle(shiftType, isOn)
                } catch {
                    refusal = (error as? PlanningRefusal)?.explanation ?? "Couldn't change your calendar."
                }
            }
        }
    }
}

/// Why the sheet can't plan, with a way to Settings to fix it.
private struct SettingsNotice: View {
    let title: String
    let message: String
    let openSettings: () -> Void

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            Button("Open Settings", systemImage: "gearshape", action: openSettings)
        }
    }
}

private extension PlanningRefusal {
    var explanation: String {
        switch self {
        case .noPlanningCalendar: "Choose a calendar you can edit in Settings."
        case .pastDay: "Past days can't be changed."
        case .alreadyPlanned: "This Shift is already on this day."
        case .locked: "This Shift can only be changed in the Calendar app."
        }
    }
}

private extension PreviewRoster {
    static let shiftTypes = [tagdienst, nachtdienst, hausrunde, ambulanz, spät]

    static func day(inDays days: Int, _ shifts: [GridShift]) -> GridDay {
        let calendar = Calendar.current
        return GridDay(
            date: calendar.date(byAdding: .day, value: days, to: calendar.startOfDay(for: .now))!,
            isInMonth: true, isToday: days == 0, isPast: days < 0, shifts: shifts)
    }

    static func shift(_ shiftType: ShiftType, isSkipped: Bool = false, isLocked: Bool = false) -> GridShift {
        GridShift(shiftType: shiftType, isSkipped: isSkipped, hasAlarmArmed: !isSkipped, isLocked: isLocked)
    }
}

private extension DaySheet {
    init(day: GridDay, shiftTypes: [ShiftType] = PreviewRoster.shiftTypes, hasPlanningCalendar: Bool = true) {
        self.init(
            day: day, shiftTypes: shiftTypes, hasPlanningCalendar: hasPlanningCalendar,
            toggle: { _, _ in }, toggleSkip: { _ in }, openSettings: {})
    }
}

#Preview("A future day") {
    DaySheet(day: PreviewRoster.day(inDays: 2, [PreviewRoster.shift(PreviewRoster.nachtdienst)]))
}

#Preview("A locked Shift") {
    DaySheet(day: PreviewRoster.day(inDays: 5, [
        PreviewRoster.shift(PreviewRoster.tagdienst, isLocked: true),
        PreviewRoster.shift(PreviewRoster.hausrunde, isSkipped: true),
    ]))
}

#Preview("A past day") {
    DaySheet(day: PreviewRoster.day(inDays: -3, [PreviewRoster.shift(PreviewRoster.hausrunde, isLocked: true)]))
}

#Preview("No Planning Calendar") {
    DaySheet(day: PreviewRoster.day(inDays: 2, []), hasPlanningCalendar: false)
}

#Preview("No Shift Types") {
    DaySheet(day: PreviewRoster.day(inDays: 2, []), shiftTypes: [])
}
