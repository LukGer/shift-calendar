import Foundation
import Testing

/// Every string the app shows has a German translation, so a German phone never falls back to English.
struct LocalizationTests {
    @Test(arguments: ["Localizable.xcstrings", "InfoPlist.xcstrings"])
    func everyStringHasAGermanTranslation(catalog: String) throws {
        let url = URL(filePath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
            .appending(path: "ShiftAlarm/\(catalog)")
        let strings = try JSONDecoder().decode(StringCatalog.self, from: Data(contentsOf: url)).strings

        #expect(!strings.isEmpty)
        #expect(strings.filter { $0.value.needsGerman }.keys.sorted() == [])
    }
}

private struct StringCatalog: Decodable {
    let strings: [String: Entry]

    struct Entry: Decodable {
        let shouldTranslate: Bool?
        let localizations: [String: Localization]?

        var needsGerman: Bool {
            shouldTranslate != false && localizations?["de"]?.isTranslated != true
        }
    }

    struct Localization: Decodable {
        let stringUnit: StringUnit?
        let variations: [String: [String: Localization]]?

        var isTranslated: Bool {
            stringUnit?.state == "translated" || variations != nil
        }
    }

    struct StringUnit: Decodable {
        let state: String
    }
}
