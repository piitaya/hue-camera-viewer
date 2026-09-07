import Foundation

private struct LocalizationFailure: Error, CustomStringConvertible {
    let description: String
}

private func require(_ condition: @autoclosure () -> Bool, _ message: String) throws {
    if !condition() { throw LocalizationFailure(description: message) }
}

private func strings(at url: URL) throws -> [String: String] {
    let data = try Data(contentsOf: url)
    guard let result = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: String] else {
        throw LocalizationFailure(description: "Invalid string table: \(url.path)")
    }
    return result
}

private func placeholders(in value: String) throws -> [String] {
    let pattern = #"%(?:[1-9][0-9]*\$)?[-+#0 ]*(?:[0-9]+|\*)?(?:\.(?:[0-9]+|\*))?(?:hh|h|ll|l|q|L|z|t|j)?[@diuoxXfFeEgGaAcCsSp%]"#
    let expression = try NSRegularExpression(pattern: pattern)
    let range = NSRange(value.startIndex..., in: value)
    return expression.matches(in: value, range: range).compactMap { match in
        guard let range = Range(match.range, in: value) else { return nil }
        return String(value[range])
    }.sorted()
}

@main
private struct LocalizationTests {
    static func main() throws {
        let args = CommandLine.arguments
        guard args.count >= 3 else {
            throw LocalizationFailure(description: "Expected source Resources path and language (en or fr)")
        }
        let resources = URL(fileURLWithPath: args[1], isDirectory: true)
        let language = args[2]
        try require(["en", "fr"].contains(language), "Unsupported expected language")
        try require(Bundle.main.preferredLocalizations.first == language,
                    "macOS did not select the requested bundle language: \(Bundle.main.preferredLocalizations)")

        for table in ["Localizable", "InfoPlist"] {
            let french = try strings(at: resources.appendingPathComponent("fr.lproj/\(table).strings"))
            let english = try strings(at: resources.appendingPathComponent("en.lproj/\(table).strings"))
            try require(Set(french.keys) == Set(english.keys), "\(table): French/English keys differ")
            for key in french.keys.sorted() {
                let source = french[key]!
                let translated = english[key]!
                try require(!source.isEmpty && !translated.isEmpty, "Empty translation: \(key)")
                let sourcePlaceholders = try placeholders(in: source)
                let translatedPlaceholders = try placeholders(in: translated)
                try require(sourcePlaceholders == translatedPlaceholders, "Mismatched placeholders: \(key)")
                let expected = language == "en" ? translated : source
                if table == "Localizable" {
                    let actual = Bundle.main.localizedString(forKey: key, value: "MISSING TRANSLATION", table: table)
                    try require(actual == expected, "Bundled \(language) translation is missing or stale: \(key)")
                } else {
                    try require(Bundle.main.object(forInfoDictionaryKey: key) as? String == expected,
                                "Info.plist localization was not loaded: \(key)")
                }
            }
        }

        // Exercise strings used outside SwiftUI, where a translated resource alone is insufficient.
        let expectedPNGError = language == "en"
            ? "The PNG capture could not be created." : "Impossible de créer la capture PNG."
        try require(ImagePipelineError.pngEncodingFailed.localizedDescription == expectedPNGError,
                    "Image pipeline errors bypass localization")
        let tooltip = String(format: NSLocalizedString("Choisir la caméra\n%@", comment: ""), "USB Camera")
        try require(tooltip == (language == "en" ? "Choose Camera\nUSB Camera" : "Choisir la caméra\nUSB Camera"),
                    "Camera tooltip lost its camera name or localization")
        print("PASS: \(language) bundle selection, all interface/permission strings, matching keys/placeholders, and localized image errors.")
    }
}
