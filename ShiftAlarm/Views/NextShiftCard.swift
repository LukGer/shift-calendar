import SwiftUI

/// The next Shift in the Arming Window: its day, Shift Type and every alarm time on one line,
/// on the Shift Type's colour.
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
                    if shift.isSkipped {
                        Text("Skipped")
                            .font(.caption.bold())
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(.white.opacity(0.25), in: .capsule)
                    }
                }
                HStack(alignment: .firstTextBaseline) {
                    Text(shift.alarmTimes.summary)
                        .font(.system(shift.alarmTimes.isEmpty ? .title3 : .title, design: .rounded).weight(.semibold))
                        .monospacedDigit()
                        .strikethrough(shift.isSkipped)
                        .opacity(shift.isSkipped ? 0.6 : 1)
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                    Spacer()
                    SkipButton(isSkipped: shift.isSkipped) { toggleSkip(shift) }
                    .font(.footnote.bold())
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .tint(.white)
                }
            }
            .foregroundStyle(.white)
            .padding(16)
            .background(shift.color.gradient, in: .rect(cornerRadius: 20))
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
        if calendar.isDateInToday(shift.date) { return "Today" }
        if calendar.isDateInTomorrow(shift.date) { return "Tomorrow" }
        return shift.date.formatted(.dateTime.weekday(.wide).day().month(.abbreviated))
    }
}

#Preview("Card states") {
    VStack(spacing: 12) {
        NextShiftCard(
            shift: .preview(inDays: 1, PreviewRoster.tagdienst, alarmTimes: ["05:00", "05:10", "05:20"]),
            toggleSkip: { _ in })
        NextShiftCard(
            shift: .preview(inDays: 2, PreviewRoster.nachtdienst, alarmTimes: ["16:30", "16:45"], isSkipped: true),
            toggleSkip: { _ in })
        NextShiftCard(shift: .preview(inDays: 0, PreviewRoster.spät, alarmTimes: []), toggleSkip: { _ in })
        NextShiftCard(shift: nil, toggleSkip: { _ in })
    }
    .padding()
    .background(Color(.systemGroupedBackground))
}
