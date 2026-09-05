import Foundation

@main
@MainActor
enum OncePressStoreTests {
    static func main() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("omg-once-tests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = directory.appendingPathComponent("once.json")
        let instant = Date(timeIntervalSince1970: 1_783_000_000)
        let zone = TimeZone(identifier: "Asia/Shanghai")!
        let first = OncePressStore(fileURL: file)
        precondition(first.record == nil)
        precondition(first.press(at: instant, timeZone: zone))
        precondition(!first.isMomentVisible)
        try await Task.sleep(nanoseconds: 200_000_000)
        precondition(first.isMomentVisible)
        precondition(!first.press(at: instant.addingTimeInterval(1), timeZone: zone))

        let reopened = OncePressStore(fileURL: file)
        precondition(reopened.isMomentVisible)
        precondition(reopened.record == first.record)
        precondition(reopened.record?.date == instant)
        precondition(reopened.record?.timeZoneIdentifier == "Asia/Shanghai")
        precondition(!reopened.press(at: .now, timeZone: TimeZone(secondsFromGMT: 0)!))

        let corrupted = Data("unreadable record".utf8)
        try corrupted.write(to: file)
        let broken = OncePressStore(fileURL: file)
        precondition(broken.errorMessage != nil)
        precondition(!broken.press(at: .now, timeZone: zone))
        let unchangedData = try Data(contentsOf: file)
        precondition(unchangedData == corrupted)

        let parentFile = directory.appendingPathComponent("not-a-directory")
        try Data().write(to: parentFile)
        let unwritable = OncePressStore(fileURL: parentFile.appendingPathComponent("once.json"))
        precondition(!unwritable.press(at: instant, timeZone: zone))
        precondition(unwritable.record == nil && unwritable.errorMessage != nil)
        print("PASS: first press, duplicate rejection, relaunch persistence, frozen time zone and safe storage failures")
    }
}
