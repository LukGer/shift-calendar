import Foundation
import SwiftData
import SwiftUI

@Model
final class ShiftType {
    var id: UUID
    var name: String
    var shortcut: String
    var colorIndex: Int
    var createdAt: Date
    private(set) var alarmSet: [AlarmTime]

    init(name: String, shortcut: String, alarmSet: [AlarmTime], colorIndex: Int, createdAt: Date = .now) {
        id = UUID()
        self.name = name
        self.shortcut = shortcut
        self.alarmSet = alarmSet.sorted()
        self.colorIndex = colorIndex
        self.createdAt = createdAt
    }

    func replaceAlarmSet(with times: [AlarmTime]) {
        alarmSet = times.sorted()
    }
}

nonisolated struct AlarmTime: Codable, Hashable, Comparable {
    var hour: Int
    var minute: Int

    static func < (lhs: AlarmTime, rhs: AlarmTime) -> Bool {
        (lhs.hour, lhs.minute) < (rhs.hour, rhs.minute)
    }

    init(hour: Int, minute: Int) {
        self.hour = hour
        self.minute = minute
    }

    init(of date: Date, calendar: Calendar) {
        let components = calendar.dateComponents([.hour, .minute], from: date)
        self.init(hour: components.hour!, minute: components.minute!)
    }

    func instant(on day: Date, calendar: Calendar) -> Date {
        calendar.date(bySettingHour: hour, minute: minute, second: 0, of: day)!
    }

    var text: String {
        String(format: "%02d:%02d", hour, minute)
    }
}

extension [AlarmTime] {
    /// "05:00 · 05:10", or "Rings nothing" when empty.
    var summary: String {
        isEmpty ? "Rings nothing" : map(\.text).joined(separator: " · ")
    }
}

extension ShiftType {
    static let palette: [Color] = [.orange, .indigo, .teal, .pink, .green, .purple, .brown, .cyan]

    var color: Color {
        Self.palette[colorIndex % Self.palette.count]
    }
}
