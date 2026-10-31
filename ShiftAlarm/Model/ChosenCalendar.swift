import Foundation
import SwiftData

/// A calendar she chose as holding her Shifts. Title and account are kept so it can be found again
/// if a calendar sync changes its identifier.
@Model
final class ChosenCalendar {
    var identifier: String
    var title: String
    var sourceIdentifier: String
    /// Marks the Planning Calendar. Defaults to false so stores from before Planning still open.
    var isPlanningCalendar = false

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

extension [ChosenCalendar] {
    /// The ones she can edit, in Settings order, each found again if a sync changed its identifier.
    func editable(among deviceCalendars: [DeviceCalendar]) -> [ChosenCalendar] {
        let found = filter { $0.isFound(among: deviceCalendars) }
        return deviceCalendars.filter(\.isEditable).compactMap { device in
            found.first { $0.identifier == device.identifier }
        }
    }

    /// The marked one while it is still chosen, found and editable; otherwise the first editable one.
    func planningCalendar(among deviceCalendars: [DeviceCalendar]) -> ChosenCalendar? {
        let editable = editable(among: deviceCalendars)
        return editable.first(where: \.isPlanningCalendar) ?? editable.first
    }

    func markAsPlanningCalendar(_ planningCalendar: ChosenCalendar) {
        forEach { $0.isPlanningCalendar = $0 === planningCalendar }
    }
}
