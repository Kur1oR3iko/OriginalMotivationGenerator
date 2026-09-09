import Foundation

@main
enum LocalizationTests {
    static func main() throws {
        precondition(AppLanguage.resolve(["zh-CN"]) == .chinese)
        precondition(AppLanguage.resolve(["zh-Hant-TW"]) == .chinese)
        precondition(AppLanguage.resolve(["ja-JP"]) == .japanese)
        precondition(AppLanguage.resolve(["en-JP"]) == .english)
        precondition(AppLanguage.resolve(["fr-FR", "zh-Hans"]) == .english)
        precondition(AppLanguage.resolve([]) == .english)
        let root = URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent("App")
        func table(_ language: String, _ name: String) throws -> [String: String] {
            let data = try Data(contentsOf: root.appendingPathComponent("\(language).lproj/\(name).strings"))
            return try PropertyListSerialization.propertyList(from: data, format: nil) as! [String: String]
        }
        let source = try table("zh-Hans", "Localizable")
        for language in ["en", "ja", "zh-Hans"] {
            let ui = try table(language, "Localizable")
            precondition(Set(source.keys).isSubset(of: Set(ui.keys)))
            precondition(ui.values.allSatisfy { !$0.isEmpty })
            let lexicon = try table(language, "Lexicon")
            precondition(lexicon.count == 675)
            for kind in ["verb", "adjective", "noun"] {
                let values = lexicon.filter { $0.key.hasPrefix(kind + ".") }.map(\.value)
                precondition(values.count == 225 && Set(values).count == 225)
            }
            let format = ui["%ld年%@"]!
            let sample = String(format: format, arguments: [2026, "Sep"])
            precondition(sample.contains("2026") && sample.contains("Sep"))
            let info = try table(language, "InfoPlist")
            precondition(info["CFBundleDisplayName"] != nil && info["NSCameraUsageDescription"] != nil)
        }
        let english = try table("en", "Lexicon")
        precondition(english["verb.折叠"] == "fold" && english["noun.黄昏"] == "twilight")
        let phrase = KurioPhraseGenerator.Phrase(verb: "折叠", adjective: "温柔", noun: "黄昏")
        precondition(phrase.canonicalText == "折叠温柔的黄昏")
        precondition(!CaptureConfiguration.enabled)
        print("PASS: language fallback, complete UI coverage, 675 unique lexicon entries per language, date formatting, names and canonical phrase preservation")
    }
}
