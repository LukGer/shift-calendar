import SwiftUI

/// A day of the month grid: her Shift Types to plan or take off, then Skip for the day's Shifts and Edit Shift Types.
/// Past days leave only Edit Shift Types; without a Planning Calendar her Shift Types are read-only.
struct DayMenu: View {
    let day: GridDay
    let shiftTypes: [ShiftType]
    let hasPlanningCalendar: Bool
    let plan: (ShiftType) -> Void
    let takeOff: (ShiftType) -> Void
    let toggleSkip: (GridShift) -> Void
    let openSettings: () -> Void

    var body: some View {
        if !shiftTypes.isEmpty {
            Section(day.isPast ? "\(day.title) · \(PlanningRefusal.pastDay.explanation)" : day.title) {
                ForEach(shiftTypes, content: shiftTypeToggle)
            }
        }
        Section {
            if !day.isPast {
                skip
            }
            Button("Edit Shift Types", systemImage: "slider.horizontal.3", action: openSettings)
        } header: {
            if let settingsReason {
                Text(settingsReason)
            }
        }
    }

    /// One Shift is Skipped straight away; with more, she picks which.
    @ViewBuilder private var skip: some View {
        if let shift = day.shifts.first, day.shifts.count == 1 {
            SkipButton(isSkipped: shift.isSkipped) { toggleSkip(shift) }
        } else if !day.shifts.isEmpty {
            Menu("Skip Shift", systemImage: "moon.zzz") {
                ForEach(day.shifts, id: \.shiftType.id) { shift in
                    Toggle(isOn: Binding { shift.isSkipped } set: { _ in toggleSkip(shift) }) {
                        Label { Text(shift.shiftType.name) } icon: { swatch(shift.shiftType.color) }
                    }
                }
            }
        }
    }

    private var settingsReason: String? {
        if shiftTypes.isEmpty { return String(localized: "Set up your Shift Types in Settings to plan Shifts.") }
        if !hasPlanningCalendar && !day.isPast { return PlanningRefusal.noPlanningCalendar.explanation }
        return nil
    }

    private func shiftTypeToggle(_ shiftType: ShiftType) -> some View {
        let shift = day.shifts.first { $0.shiftType.id == shiftType.id }
        let isPlanned = Binding { shift != nil } set: { $0 ? plan(shiftType) : takeOff(shiftType) }
        return Toggle(isOn: isPlanned) {
            Label {
                Text(shiftType.name)
                if shift?.isLocked == true && !day.isPast {
                    Text("Edit in Calendar")
                }
            } icon: {
                swatch(shiftType.color)
            }
        }
        .disabled(day.isPast || !hasPlanningCalendar || shift?.isLocked == true)
    }

    /// Menus tint their icons, so the colour is baked into the image.
    private func swatch(_ color: Color) -> Image {
        Image(uiImage: UIImage(systemName: "circle.fill")!
            .withTintColor(UIColor(color), renderingMode: .alwaysOriginal))
    }
}

extension PlanningRefusal {
    var explanation: String {
        switch self {
        case .noPlanningCalendar: String(localized: "Choose a calendar you can edit in Settings.")
        case .pastDay: String(localized: "Past days can't be changed.")
        case .alreadyPlanned: String(localized: "This Shift is already on this day.")
        case .locked: String(localized: "This Shift can only be changed in the Calendar app.")
        }
    }
}

private extension PreviewCalendarStore {
    static func day(inDays days: Int, _ shifts: [GridShift]) -> GridDay {
        GridDay(
            date: date(inDays: days),
            isInMonth: true, isToday: days == 0, isPast: days < 0, shifts: shifts)
    }

    static func shift(_ shiftType: ShiftType, isSkipped: Bool = false, isLocked: Bool = false) -> GridShift {
        GridShift(shiftType: shiftType, isSkipped: isSkipped, isLocked: isLocked)
    }
}

private extension DayMenu {
    init(day: GridDay, shiftTypes: [ShiftType] = PreviewCalendarStore.shiftTypes, hasPlanningCalendar: Bool = true) {
        self.init(
            day: day, shiftTypes: shiftTypes, hasPlanningCalendar: hasPlanningCalendar,
            plan: { _ in }, takeOff: { _ in }, toggleSkip: { _ in }, openSettings: {})
    }
}

#Preview("A future day") {
    Menu("A future day") {
        DayMenu(day: PreviewCalendarStore.day(inDays: 2, [PreviewCalendarStore.shift(PreviewCalendarStore.nachtdienst)]))
    }
}

#Preview("A locked Shift") {
    Menu("A locked Shift") {
        DayMenu(day: PreviewCalendarStore.day(inDays: 5, [
            PreviewCalendarStore.shift(PreviewCalendarStore.tagdienst, isLocked: true),
            PreviewCalendarStore.shift(PreviewCalendarStore.hausrunde, isSkipped: true),
        ]))
    }
}

#Preview("A past day") {
    Menu("A past day") {
        DayMenu(day: PreviewCalendarStore.day(inDays: -3, [
            PreviewCalendarStore.shift(PreviewCalendarStore.hausrunde, isLocked: true),
        ]))
    }
}

#Preview("No Planning Calendar") {
    Menu("No Planning Calendar") {
        DayMenu(day: PreviewCalendarStore.day(inDays: 2, []), hasPlanningCalendar: false)
    }
}

#Preview("No Shift Types") {
    Menu("No Shift Types") {
        DayMenu(day: PreviewCalendarStore.day(inDays: 2, []), shiftTypes: [])
    }
}
