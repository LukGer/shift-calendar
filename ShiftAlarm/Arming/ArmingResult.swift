import Foundation
import SwiftUI

/// What an Arming run reports. The home screen renders from it.
enum ArmingResult: Equatable {
    /// The Shifts in the Arming Window, in date order.
    case armed([WindowShift])
    /// Changed nothing, because the run couldn't see enough to change alarms safely.
    case skipped(SkipReason)
    case failed
}

nonisolated enum SkipReason {
    case calendarNotReadable
    case chosenCalendarMissing
    case alarmsNotAllowed
}

/// A Shift in the Arming Window as the home screen shows it, whether it rings, is skipped or rings nothing.
struct WindowShift: Equatable, Identifiable {
    let date: Date
    let shiftTypeID: UUID
    let name: String
    let color: Color
    /// The times that will ring, or would if the Shift weren't skipped; empty when the Shift Type's Alarm Set is empty.
    let alarmTimes: [AlarmTime]
    let isSkipped: Bool

    var id: String {
        "\(date.timeIntervalSinceReferenceDate)|\(shiftTypeID)"
    }
}
