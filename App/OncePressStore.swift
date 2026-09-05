import Foundation
import Combine

@MainActor
final class OncePressStore: ObservableObject {
    struct Record: Codable, Equatable {
        let date: Date
        let timeZoneIdentifier: String

        var timeZone: TimeZone { TimeZone(identifier: timeZoneIdentifier) ?? TimeZone(secondsFromGMT: 0)! }
    }

    static let shared = OncePressStore()
    @Published private(set) var record: Record?
    @Published private(set) var errorMessage: String?
    @Published private(set) var isMomentVisible = true
    private let fileURL: URL
    private var unreadableRecord = false

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("OriginalMotivationGenerator", isDirectory: true)
            .appendingPathComponent("once-press.json")
        readExistingRecord()
    }

    /// Returns true only for the first successfully saved press. No reset operation is exposed.
    @discardableResult
    func press(at date: Date = .now, timeZone: TimeZone) -> Bool {
        guard record == nil, !unreadableRecord else { return false }
        readExistingRecord()
        guard record == nil, !unreadableRecord else { return false }
        let newRecord = Record(date: date, timeZoneIdentifier: timeZone.identifier)
        do {
            let data = try JSONEncoder().encode(newRecord)
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: fileURL, options: .atomic)
            errorMessage = nil
            isMomentVisible = false
            record = newRecord
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 100_000_000)
                self?.isMomentVisible = true
            }
            return true
        } catch {
            errorMessage = "暂时无法保存按下记录，请稍后再试。"
            return false
        }
    }

    private func readExistingRecord() {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return }
        do {
            record = try JSONDecoder().decode(Record.self, from: Data(contentsOf: fileURL))
        } catch {
            // Never treat a damaged or inaccessible existing record as an unused opportunity.
            unreadableRecord = true
            errorMessage = "无法读取已有的按下记录。"
        }
    }
}
