import SwiftUI

/// The next Shift in the Arming Window: its day and Shift Type with a button to Skip it, then every alarm time on
/// one line, on the Shift Type's colour. Skipping strikes the times through and stripes and fades the colour.
struct NextShiftCard: View {
    let shift: WindowShift?
    let toggleSkip: (WindowShift) -> Void

    var body: some View {
        if let shift {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("\(dayTitle(of: shift)) · \(shift.name)")
                        .font(.subheadline.bold())
                    Spacer()
                    if !shift.alarmTimes.isEmpty {
                        SkipToggle(isSkipped: shift.isSkipped) { toggleSkip(shift) }
                    }
                }
                .frame(minHeight: 30)
                Text(shift.alarmTimes.summary)
                    .font(.system(shift.alarmTimes.isEmpty ? .title3 : .title, design: .rounded).weight(.semibold))
                    .monospacedDigit()
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
                    .opacity(shift.isSkipped ? 0.6 : 1)
                    .overlay(alignment: .leading) {
                        Capsule()
                            .frame(height: 3)
                            .scaleEffect(x: shift.isSkipped ? 1 : 0, anchor: .leading)
                            .opacity(shift.isSkipped ? 0.8 : 0)
                    }
                    .contentTransition(.numericText())
            }
            .foregroundStyle(.white)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                Rectangle()
                    .fill(shift.color.gradient)
                    .saturation(shift.isSkipped ? 0.3 : 1)
                Hatching(progress: shift.isSkipped ? 1 : 0, spacing: 12)
                    .stroke(.white.opacity(0.15), lineWidth: 4)
            }
            .clipShape(.rect(cornerRadius: 20))
            .animation(.spring(duration: 0.6, bounce: 0.25), value: shift)
            .sensoryFeedback(.impact(weight: .light), trigger: shift.isSkipped)
        } else {
            VStack(alignment: .leading, spacing: 4) {
                Label("No Shifts this week", systemImage: "calendar")
                    .font(.headline)
                Text("Days without a Shift ring nothing.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background, in: .rect(cornerRadius: 20))
        }
    }

    private func dayTitle(of shift: WindowShift) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(shift.date) { return String(localized: "Today") }
        if calendar.isDateInTomorrow(shift.date) { return String(localized: "Tomorrow") }
        return shift.date.formatted(.dateTime.weekday(.wide).day().month(.abbreviated))
    }
}

/// "Skip" with a sleeping moon, or "Ring" with a bell once Skipped. The symbol morphs from one to the other.
private struct SkipToggle: View {
    let isSkipped: Bool
    let toggle: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: 4) {
                Image(systemName: isSkipped ? "bell" : "moon.zzz")
                    .contentTransition(.symbolEffect(.replace.downUp))
                    .symbolEffect(.bounce, value: isSkipped)
                Text(isSkipped ? "Ring" : "Skip")
                    .contentTransition(.interpolate)
            }
        }
        .font(.footnote.bold())
        .buttonStyle(.bordered)
        .controlSize(.small)
        .tint(.white)
        .accessibilityLabel(isSkipped ? "Ring for this Shift" : "Skip this Shift")
    }
}

#Preview("Card states") {
    VStack(spacing: 12) {
        NextShiftCard(
            shift: .preview(inDays: 1, PreviewCalendarStore.tagdienst, alarmTimes: ["05:00", "05:10", "05:20"]),
            toggleSkip: { _ in })
        NextShiftCard(
            shift: .preview(inDays: 2, PreviewCalendarStore.nachtdienst, alarmTimes: ["16:30", "16:45"], isSkipped: true),
            toggleSkip: { _ in })
        NextShiftCard(shift: .preview(inDays: 0, PreviewCalendarStore.spät, alarmTimes: []), toggleSkip: { _ in })
        NextShiftCard(shift: nil, toggleSkip: { _ in })
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}

#Preview("Skipping") {
    @Previewable @State var isSkipped = false
    NextShiftCard(
        shift: .preview(inDays: 1, PreviewCalendarStore.tagdienst, alarmTimes: ["05:00", "05:10"], isSkipped: isSkipped),
        toggleSkip: { _ in isSkipped.toggle() })
        .padding()
        .background(Color(.systemGroupedBackground))
}
