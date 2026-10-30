import Foundation
import SwiftData

/// Her choice that one Shift rings nothing. It is tied to the date and Shift Type rather than to the event,
/// so it survives the event being deleted and added again, and stops applying if the Shift Type changes.
@Model
final class Skip {
    var date: Date
    var shiftTypeID: UUID

    init(date: Date, shiftTypeID: UUID) {
        self.date = date
        self.shiftTypeID = shiftTypeID
    }
}

extension Shift {
    func isSkipped(by skips: [Skip]) -> Bool {
        skips.contains { $0.date == date && $0.shiftTypeID == shiftType.id }
    }
}

extension ModelContext {
    /// Skips the Shift, or un-skips it if it is skipped. The next Arming run cancels or re-arms its alarms.
    func toggleSkip(of shift: WindowShift) throws {
        let date = shift.date
        let shiftTypeID = shift.shiftTypeID
        let skips = try fetch(FetchDescriptor<Skip>(
            predicate: #Predicate { $0.date == date && $0.shiftTypeID == shiftTypeID }))
        if skips.isEmpty {
            insert(Skip(date: date, shiftTypeID: shiftTypeID))
        } else {
            skips.forEach(delete)
        }
        try save()
    }
}
