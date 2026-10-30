import Foundation
import SwiftData

/// A calendar she chose as holding her Shifts. Title and account are kept so it can be found again
/// if a calendar sync changes its identifier.
@Model
final class ChosenCalendar {
    var identifier: String
    var title: String
    var sourceIdentifier: String

    init(identifier: String, title: String, sourceIdentifier: String) {
        self.identifier = identifier
        self.title = title
        self.sourceIdentifier = sourceIdentifier
    }

    /// Whether it is among the device's calendars. If its identifier is gone, it takes the identifier of
    /// the one calendar with the same title in the same account; with none or several, it is missing.
    func isFound(among calendars: [DeviceCalendar]) -> Bool {
        if calendars.contains(where: { $0.identifier == identifier }) { return true }
        let sameTitleAndAccount = calendars.filter { $0.title == title && $0.sourceIdentifier == sourceIdentifier }
        guard sameTitleAndAccount.count == 1 else { return false }
        identifier = sameTitleAndAccount[0].identifier
        return true
    }
}
