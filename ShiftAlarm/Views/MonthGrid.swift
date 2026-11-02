import SwiftUI

/// Months of Shifts in weeks that start on the locale's first weekday. Swipe sideways or use the arrows to
/// change month, and tap a day for what she can do with it.
struct MonthGrid<DayMenu: View>: View {
    /// The first day of the month on screen.
    @Binding var month: Date
    /// The month on screen and its neighbours, keyed by their first day.
    let daysByMonth: [Date: [GridDay]]
    let calendar: Calendar
    @ViewBuilder let dayMenu: (GridDay) -> DayMenu
    /// Months have five or six weeks, so the pager takes the height of the month on screen.
    @State private var heights: [Date: CGFloat] = [:]

    var body: some View {
        ScrollView(.horizontal) {
            LazyHStack(alignment: .top, spacing: 0) {
                ForEach(months, id: \.self) { page in
                    MonthPage(
                        month: page, days: daysByMonth[page] ?? [], calendar: calendar, show: show, dayMenu: dayMenu)
                        .fixedSize(horizontal: false, vertical: true)
                        .onGeometryChange(for: CGFloat.self, of: \.size.height) { heights[page] = $0 }
                        .padding(.horizontal)
                        .containerRelativeFrame(.horizontal)
                }
            }
            .scrollTargetLayout()
        }
        .scrollTargetBehavior(.viewAligned(limitBehavior: .alwaysByOne))
        .scrollPosition(id: Binding { month } set: { if let page = $0 { month = page } })
        .scrollIndicators(.hidden)
        .frame(height: heights[month])
        .animation(.smooth, value: heights[month])
        .sensoryFeedback(.selection, trigger: month)
    }

    private var thisMonth: Date {
        calendar.dateInterval(of: .month, for: .now)!.start
    }

    /// Ten years either side of this month.
    private var months: [Date] {
        (-120...120).map { calendar.date(byAdding: .month, value: $0, to: thisMonth)! }
    }

    /// Scrolls `months` away from the month on screen, or back to this month when nil.
    private func show(_ months: Int?) {
        withAnimation(.smooth) {
            month = months.map { calendar.date(byAdding: .month, value: $0, to: month)! } ?? thisMonth
        }
    }
}

private struct MonthPage<DayMenu: View>: View {
    let month: Date
    let days: [GridDay]
    let calendar: Calendar
    let show: (_ months: Int?) -> Void
    let dayMenu: (GridDay) -> DayMenu

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 12) {
                Button { show(nil) } label: {
                    Text(month, format: .dateTime.month(.wide).year())
                        .font(.title3.bold())
                }
                .buttonStyle(.plain)
                .accessibilityHint("Shows this month")
                Spacer()
                Button("Previous month", systemImage: "chevron.left") { show(-1) }
                Button("Next month", systemImage: "chevron.right") { show(1) }
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
                            Menu { dayMenu(day) } label: { DayCell(day: day) }
                                .menuStyle(.button)
                                .buttonStyle(.plain)
                                .menuOrder(.fixed)
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(.background, in: .rect(cornerRadius: 20))
    }

    private var weekdaySymbols: [String] {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let first = calendar.firstWeekday - 1
        return Array(symbols[first...] + symbols[..<first])
    }
}

/// The day's number, then its Shifts sharing the space below it. A Shift slides in from the bottom when it's planned.
private struct DayCell: View {
    let day: GridDay

    var body: some View {
        VStack(spacing: 2) {
            dayNumber
            VStack(spacing: 0) {
                ForEach(day.shifts, id: \.shiftType.id) { shift in
                    ShiftTile(shift: shift)
                        .transition(.move(edge: .bottom))
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .clipShape(.rect(cornerRadius: 5))
        }
        .padding([.horizontal, .bottom], 3)
        .frame(maxWidth: .infinity, minHeight: 62)
        .background(RoundedRectangle(cornerRadius: 8).strokeBorder(.quaternary, lineWidth: 0.5))
        .contentShape(.rect)
        .opacity(day.isInMonth ? 1 : 0.4)
        .animation(.snappy, value: day.shifts)
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
            .frame(height: 25, alignment: .bottom)
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

/// A Shift's Shortcut on its Shift Type's colour. Stripes sweep in when it's Skipped.
private struct ShiftTile: View {
    let shift: GridShift

    var body: some View {
        let color = shift.shiftType.color
        Text(shift.shiftType.shortcut)
            .font(.caption.bold())
            .foregroundStyle(color)
            .lineLimit(1)
            .minimumScaleFactor(0.6)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background {
                color.opacity(shift.isSkipped ? 0.08 : 0.2)
                Hatching(progress: shift.isSkipped ? 1 : 0)
                    .stroke(color.opacity(0.3), lineWidth: 1.5)
            }
    }
}

#Preview("Busy month") {
    @Previewable @State var month = Calendar.current.dateInterval(of: .month, for: .now)!.start
    MonthGrid(month: $month, daysByMonth: [month: PreviewCalendarStore.busyMonth], calendar: .current) { day in
        Text(day.title)
    }
    .background(Color(.systemGroupedBackground))
}
