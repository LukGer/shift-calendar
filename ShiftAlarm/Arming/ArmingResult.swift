import Foundation
import SwiftUI

/// What an Arming run reports. The home screen renders from it.
enum ArmingResult: Equatable {
    /// The Shifts in the Arming Window, in date order.
    case armed([ArmedShift])
    case failed
}

struct ArmedShift: Equatable, Identifiable {
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
