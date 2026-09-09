import Foundation

enum AppLanguage: String, CaseIterable {
    case chinese = "zh-Hans", english = "en", japanese = "ja"

    static func resolve(_ preferred: [String]) -> AppLanguage {
        let first = (preferred.first ?? "en").lowercased().replacingOccurrences(of: "_", with: "-")
        if first == "zh" || first.hasPrefix("zh-") { return .chinese }
        if first == "ja" || first.hasPrefix("ja-") { return .japanese }
        return .english
    }
}

enum L10n {
    static let language = AppLanguage.resolve(Locale.preferredLanguages)
    static var locale: Locale { Locale(identifier: language.rawValue) }
    static let bundle: Bundle = {
        guard let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
              let localized = Bundle(path: path) else { return Bundle.main }
        return localized
    }()

    static func word(_ source: String, kind: String) -> String {
        guard language != .chinese else { return source }
        return bundle.localizedString(forKey: kind + "." + source, value: source, table: "Lexicon")
    }

    static var weekdays: [String] {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = Calendar(identifier: .gregorian)
        let names = formatter.shortWeekdaySymbols!
        return Array(names.dropFirst()) + [names[0]]
    }

    static func monthName(_ month: Int) -> String {
        let formatter = DateFormatter()
        formatter.locale = locale
        formatter.calendar = Calendar(identifier: .gregorian)
        return formatter.shortMonthSymbols[month - 1]
    }
}

func L(_ key: String, _ arguments: CVarArg...) -> String {
    var value = L10n.bundle.localizedString(forKey: key, value: key, table: "Localizable")
    if L10n.language == .english, arguments.count == 1, let count = arguments[0] as? Int, count == 1 {
        value = L10n.bundle.localizedString(forKey: key + ".one", value: value, table: "Localizable")
    }
    // Keep integer identifiers such as years ungrouped (2026, never 2,026).
    return arguments.isEmpty ? value : String(format: value, arguments: arguments)
}

/// Isolated, debug-only sample data for genuine Simulator screenshots. Release builds cannot enable it.
enum CaptureConfiguration {
    static var enabled: Bool {
        #if DEBUG
        return Bundle.main.bundleIdentifier?.hasSuffix(".screenshots") == true && ProcessInfo.processInfo.arguments.contains("--capture")
        #else
        return false
        #endif
    }

    static var pageIndex: Int {
        guard enabled, let index = ProcessInfo.processInfo.arguments.firstIndex(of: "--capture-page"),
              ProcessInfo.processInfo.arguments.indices.contains(index + 1) else { return 0 }
        return Int(ProcessInfo.processInfo.arguments[index + 1]) ?? 0
    }
    static var showsSettings: Bool { enabled && ProcessInfo.processInfo.arguments.contains("--capture-settings") }

    static func prepare() {
        #if DEBUG
        guard enabled else { return }
        let defaults = UserDefaults.standard
        defaults.set("折叠温柔的黄昏", forKey: "originalMotivationGenerator.v1.lastPhrase")
        defaults.set(false, forKey: "originalMotivationGenerator.v1.autoAdvanceEnabled")
        defaults.set(true, forKey: "originalMotivationGenerator.v1.clockShowsDate")
        defaults.set(true, forKey: "originalMotivationGenerator.v1.clockShowsSeconds")
        defaults.set("Australia/Melbourne", forKey: "originalMotivationGenerator.v1.clockTimeZone")
        let now = Date.now.timeIntervalSinceReferenceDate
        let death: [String: Any] = ["age": 32, "expectancy": 80, "startedAt": now, "timeZoneIdentifier": "Australia/Melbourne"]
        let garden: [String: Any] = ["seconds": 30 * 86_400, "date": now, "phase": "observing", "seed": 42,
                                     "observedSeconds": 0, "habitatSeconds": 30 * 86_400]
        do {
            defaults.set(try JSONSerialization.data(withJSONObject: death), forKey: "originalMotivationGenerator.v1.deathClockProfile")
            defaults.set(try JSONSerialization.data(withJSONObject: garden), forKey: "originalMotivationGenerator.v2.dormancyGarden")
            let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
                .appendingPathComponent("OriginalMotivationGenerator", isDirectory: true)
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            let traces = (0..<24).map { 1.4 + 4.8 * abs(sin(Double($0) * 0.47 + 0.2)) }
            try JSONEncoder().encode(traces).write(to: directory.appendingPathComponent("breath-marks.json"), options: .atomic)
        } catch {
            print("Screenshot sample data could not be prepared: \(error)")
        }
        #endif
    }
}
