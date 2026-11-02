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
    private(set) var alarmSet: [Alarm]

    init(name: String, shortcut: String, alarmSet: [Alarm], colorIndex: Int, createdAt: Date = .now) {
        id = UUID()
        self.name = name
        self.shortcut = shortcut
        self.alarmSet = alarmSet.inTimeOrder
        self.colorIndex = colorIndex
        self.createdAt = createdAt
    }

    func replaceAlarmSet(with alarms: [Alarm]) {
        alarmSet = alarms.inTimeOrder
    }
}

/// One alarm of an Alarm Set. Saved flat, as `{"hour", "minute", "tone"}`, so Alarm Sets saved before Tones still load;
/// a Tone that no longer ships rings the default sound.
nonisolated struct Alarm: Codable, Hashable {
    var time: AlarmTime
    var tone: Tone?

    private enum CodingKeys: CodingKey {
        case tone
    }

    init(time: AlarmTime, tone: Tone?) {
        self.time = time
        self.tone = tone
    }

    init(from decoder: any Decoder) throws {
        time = try AlarmTime(from: decoder)
        tone = (try? decoder.container(keyedBy: CodingKeys.self).decodeIfPresent(Tone.self, forKey: .tone)) ?? nil
    }

    func encode(to encoder: any Encoder) throws {
        try time.encode(to: encoder)
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encodeIfPresent(tone, forKey: .tone)
    }
}

extension Sequence<Alarm> {
    var inTimeOrder: [Alarm] {
        sorted { $0.time < $1.time }
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

    static let lastOfDay = AlarmTime(hour: 23, minute: 59)

    /// Never later than 23:59, as an alarm rings on its Shift's own date.
    func adding(minutes: Int) -> AlarmTime {
        let total = min(hour * 60 + minute + minutes, Self.lastOfDay.hour * 60 + Self.lastOfDay.minute)
        return AlarmTime(hour: total / 60, minute: total % 60)
    }
}

extension Collection<AlarmTime> {
    /// "05:00 · 05:10", or "Rings nothing" when empty.
    var summary: String {
        isEmpty ? String(localized: "Rings nothing") : map(\.text).joined(separator: " · ")
    }
}

extension ShiftType {
    static let palette: [Color] = [.orange, .indigo, .teal, .pink, .green, .purple, .brown, .cyan]

    var color: Color {
        Self.palette[colorIndex % Self.palette.count]
    }
}

extension [ShiftType] {
    var nextColorIndex: Int {
        (map(\.colorIndex).max() ?? -1) + 1
    }
}

extension ModelContext {
    /// Adds a Shift Type in the colour she picked, or else the palette's next colour, so colours follow creation order.
    @discardableResult
    func addShiftType(
        name: String, shortcut: String, alarmSet: [Alarm] = [], colorIndex: Int? = nil
    ) throws -> ShiftType {
        let colorIndex = try colorIndex ?? fetch(FetchDescriptor<ShiftType>()).nextColorIndex
        let shiftType = ShiftType(name: name, shortcut: shortcut, alarmSet: alarmSet, colorIndex: colorIndex)
        insert(shiftType)
        return shiftType
    }

    /// Makes each Shortcut she named a Shift Type that rings nothing until she gives it an Alarm Set in Settings.
    /// A Shortcut left unnamed stays ignored.
    func addShiftTypes(for shortcuts: [String], named names: [String: String]) throws {
        for shortcut in shortcuts {
            let name = (names[shortcut] ?? "").trimmed
            if !name.isEmpty {
                try addShiftType(name: name, shortcut: shortcut)
            }
        }
        try save()
    }
}
