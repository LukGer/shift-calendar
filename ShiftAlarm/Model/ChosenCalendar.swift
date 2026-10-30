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
}
