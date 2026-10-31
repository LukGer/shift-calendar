import SwiftUI

/// A month of Shifts in weeks that start on the locale's first weekday. Swipe sideways or use the arrows to
/// change month, and tap a day to open it.
struct MonthGrid: View {
    let month: Date
    let days: [GridDay]
    let calendar: Calendar
    /// Moves by this many months.
    let showMonth: (Int) -> Void
    let openDay: (GridDay) -> Void

    var body: some View {
        VStack(spacing: 6) {
            HStack {
                Text(month, format: .dateTime.month(.wide).year())
                    .font(.title3.bold())
                Spacer()
                Button("Previous month", systemImage: "chevron.left") { showMonth(-1) }
                    .padding(.trailing, 12)
                Button("Next month", systemImage: "chevron.right") { showMonth(1) }
            }
            .labelStyle(.iconOnly)
            .padding(.bottom, 4)
            Grid(horizontalSpacing: 3, verticalSpacing: 3) {
                GridRow {
                    ForEach(Array(weekdaySymbols.enumerated()), id: \.offset) { _, symbol in
                        Text(symbol)
                            .font(.caption2.bold())
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                }
                ForEach(Array(stride(from: 0, to: days.count, by: 7)), id: \.self) { weekStart in
                    GridRow {
                        ForEach(days[weekStart..<weekStart + 7]) { day in
                            Button { openDay(day) } label: { DayCell(day: day) }
                                .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(.background, in: .rect(cornerRadius: 20))
        .simultaneousGesture(DragGesture(minimumDistance: 30).onEnded { drag in
            let width = drag.translation.width
            guard abs(width) > abs(drag.translation.height) else { return }
            showMonth(width < 0 ? 1 : -1)
        })
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }
}

private struct DayCell: View {
    let day: GridDay

    /// Each Shift gets its own tinted part of the day, the first one under the day's number.
    var body: some View {
        VStack(spacing: 0) {
            if day.shifts.isEmpty {
                dayNumber
                    .frame(maxHeight: .infinity, alignment: .top)
            }
            ForEach(Array(day.shifts.enumerated()), id: \.element.shiftType.id) { index, shift in
                VStack(spacing: 1) {
                    if index == 0 {
                        dayNumber
                    }
                    Text(shift.shiftType.shortcut)
                        .font(.caption.bold())
                        .foregroundStyle(shift.isSkipped ? AnyShapeStyle(.secondary) : AnyShapeStyle(shift.shiftType.color))
                        .strikethrough(shift.isSkipped)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                .background(ShiftTint(shift: shift))
            }
        }
        .frame(maxWidth: .infinity, minHeight: 62)
        .clipShape(.rect(cornerRadius: 8))
        .overlay(alignment: .topTrailing) {
            if day.shifts.contains(where: \.hasAlarmArmed) {
                Image(systemName: "bell.fill")
                    .font(.system(size: 8))
                    .foregroundStyle(.secondary)
                    .padding(4)
            }
        }
        .opacity(day.isInMonth ? 1 : 0.4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityLabel)
    }

    private var dayNumber: some View {
        Text(day.date, format: .dateTime.day())
            .font(.caption.weight(day.isToday ? .bold : .medium))
            .foregroundStyle(day.isToday ? .white : .primary)
            .frame(width: 22, height: 22)
            .background {
                if day.isToday {
                    Circle().fill(.red)
                }
            }
            .padding(.top, 3)
    }

    private var accessibilityLabel: String {
        let shifts = day.shifts.map { $0.isSkipped ? "\($0.shiftType.name), Skipped" : $0.shiftType.name }
        return ([day.title] + (day.isToday ? ["Today"] : []) + shifts).joined(separator: ", ")
    }
}

extension GridDay {
    var title: String {
        date.formatted(.dateTime.weekday(.wide).day().month(.wide))
    }
}

/// A Shift's part of its day: tinted in its Shift Type's colour, or faded and hatched when Skipped.
private struct ShiftTint: View {
    let shift: GridShift

    var body: some View {
        let color = shift.shiftType.color
        if shift.isSkipped {
            Hatching()
                .stroke(color.opacity(0.3), lineWidth: 1.5)
                .background(color.opacity(0.08))
        } else {
            color.opacity(0.2)
        }
    }
}

private struct Hatching: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let spacing: CGFloat = 6
        var x = rect.minX - rect.height
        while x < rect.maxX {
            path.move(to: CGPoint(x: x, y: rect.maxY))
            path.addLine(to: CGPoint(x: x + rect.height, y: rect.minY))
            x += spacing
        }
        return path
    }
}

#Preview("Busy month") {
    MonthGrid(
        month: .now, days: PreviewRoster.busyMonth, calendar: .current, showMonth: { _ in },
        openDay: { _ in })
        .padding()
        .background(Color(.systemGroupedBackground))
}
