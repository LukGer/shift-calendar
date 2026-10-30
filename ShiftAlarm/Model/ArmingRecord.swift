import Foundation
import SwiftData

/// When a run last armed successfully, for the Settings status. There is only ever one.
@Model
final class ArmingRecord {
    var lastArmed: Date?

    init() {}
}
