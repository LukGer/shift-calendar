import Foundation
import SwiftData

/// What the Arming runs did, for the Settings status and the home banner. There is only ever one.
@Model
final class ArmingRecord {
    /// When a run last armed successfully.
    var lastArmed: Date?
    var latestOutcome: ArmingOutcome

    init(latestOutcome: ArmingOutcome) {
        self.latestOutcome = latestOutcome
    }
}

nonisolated enum ArmingOutcome: Codable, Equatable {
    case armed
    case skipped(SkipReason)
    case failed
}
