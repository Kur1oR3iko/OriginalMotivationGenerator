import Foundation
import Combine

@MainActor
final class BreathStore: ObservableObject {
    static let shared = BreathStore()
    struct Mark: Identifiable {
        let id: Int
        let duration: TimeInterval
    }
    @Published private(set) var marks: [Mark] = []
    var durations: [TimeInterval] { marks.map(\.duration) }
    @Published private(set) var beganAt: TimeInterval?
    @Published private(set) var errorMessage: String?
    private(set) var capacity = 60
    private var nextMarkID = 0
    private let fileURL: URL
    private var unreadableRecord = false

    init(fileURL: URL? = nil) {
        self.fileURL = fileURL ?? FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("OriginalMotivationGenerator", isDirectory: true)
            .appendingPathComponent("breath-marks.json")
        guard FileManager.default.fileExists(atPath: self.fileURL.path) else { return }
        do {
            let saved = try JSONDecoder().decode([TimeInterval].self, from: Data(contentsOf: self.fileURL))
            guard saved.allSatisfy({ $0.isFinite && $0 > 0 }) else { throw CocoaError(.fileReadCorruptFile) }
            marks = saved.suffix(512).enumerated().map { Mark(id: $0.offset, duration: $0.element) }
            nextMarkID = marks.count
        } catch {
            unreadableRecord = true
            errorMessage = L("暂时无法读取已有的呼吸线条。")
        }
    }

    func begin(at uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        guard beganAt == nil else { return }
        beganAt = uptime
    }

    func end(at uptime: TimeInterval = ProcessInfo.processInfo.systemUptime) {
        guard let start = beganAt else { return }
        beganAt = nil
        guard uptime > start else { return }
        marks.append(Mark(id: nextMarkID, duration: uptime - start))
        nextMarkID += 1
        trim()
        save()
    }

    func cancel() { beganAt = nil }
    func discard() {
        beganAt = nil
        marks = []
        unreadableRecord = false
        save()
    }

    func resize(capacity: Int) {
        self.capacity = min(512, max(1, capacity))
        let previousCount = marks.count
        trim()
        if marks.count != previousCount { save() }
    }

    private func trim() {
        if marks.count > capacity { marks.removeFirst(marks.count - capacity) }
    }

    private func save() {
        guard !unreadableRecord else { return }
        do {
            let data = try JSONEncoder().encode(durations)
            try FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try data.write(to: fileURL, options: .atomic)
            errorMessage = nil
        } catch {
            errorMessage = L("呼吸线条暂时无法保存，请稍后再试。")
        }
    }

    static func widthFraction(for duration: TimeInterval) -> Double {
        1 - exp(-max(0, duration) / 6)
    }
}

@MainActor
final class ApplicationStore: ObservableObject {
    enum Stage { case editing, waiting, approved, entered }
    @Published var applicant = ""
    @Published var reason = ""
    @Published private(set) var stage: Stage = .editing
    @Published private(set) var approvalDate: Date?

    var canSubmit: Bool {
        stage == .editing && !applicant.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            && !reason.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    @discardableResult
    func submit(at now: Date = .now, delay: TimeInterval = .random(in: 2...5)) -> Bool {
        guard canSubmit else { return false }
        approvalDate = now.addingTimeInterval(max(0, delay))
        stage = .waiting
        return true
    }

    func advance(at now: Date = .now) {
        guard stage == .waiting, let date = approvalDate, now >= date else { return }
        stage = .approved
    }

    func enter() {
        guard stage == .approved else { return }
        stage = .entered
    }

    func startAgain() {
        approvalDate = nil
        applicant = ""
        reason = ""
        stage = .editing
    }
}

/// The month controls how many individuals have arrived; each has its own short growth cycle.
enum GardenPopulation {
    static let flowerCount = 33
    static let grassCount = 72

    struct Life {
        let ageDays: Double
        let maturationDays: Double
        var maturity: Double { min(1, max(0, ageDays / maturationDays)) }
        var size: Double {
            let t = maturity
            return t * t * (3 - 2 * t)
        }
        func ageProgress(from start: Double, to end: Double) -> Double {
            min(1, max(0, (ageDays - start) / (end - start)))
        }
    }

    static func flower(index: Int, growth: Double) -> Life {
        // Scatter successive arrivals across the garden rather than filling it from left to right.
        let rank = ((index - 13 + flowerCount) * 28) % flowerCount
        return life(rank: rank, count: flowerCount, maturationDays: 0.5, growth: growth)
    }

    static func grass(index: Int, growth: Double) -> Life {
        let rank = (index * 31 + 19) % grassCount
        return life(rank: rank, count: grassCount, maturationDays: 0.4, growth: growth)
    }

    static func establishedFlower(near target: Int, growth: Double) -> Int? {
        (0..<flowerCount).filter { flower(index: $0, growth: growth).maturity >= 0.9 }
            .min { abs($0 - target) < abs($1 - target) }
    }

    private static func life(rank: Int, count: Int, maturationDays: Double, growth: Double) -> Life {
        let birthday = Double(rank) * (30 - maturationDays) / Double(count - 1)
        return Life(ageDays: min(1, max(0, growth)) * 30 - birthday, maturationDays: maturationDays)
    }
}

@MainActor
final class DormancyStore: ObservableObject {
    enum Phase: String, Codable { case locked, observing }
    struct Record: Codable {
        var seconds: TimeInterval
        var date: Date
        var phase: Phase
        let seed: UInt64
        var observedSeconds: TimeInterval? = nil
        var habitatSeconds: TimeInterval? = nil
    }
    private struct LegacyRecord: Codable {
        let restSeconds: TimeInterval
        let restingSince: Date?
        let seed: UInt64
    }

    static let shared = DormancyStore()
    static let maximumSeconds: TimeInterval = 30 * 86_400
    static let observationRate: Double = 600
    @Published private(set) var record: Record
    private let defaults: UserDefaults
    private let key = "originalMotivationGenerator.v2.dormancyGarden"
    private var visibleScenes: Set<UUID> = []

    init(defaults: UserDefaults = .standard, at now: Date = .now) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key), var saved = try? JSONDecoder().decode(Record.self, from: data),
           saved.seconds.isFinite, saved.seconds >= 0, saved.date.timeIntervalSinceReferenceDate.isFinite {
            // A suspended observer does not consume time while the application is closed.
            if saved.phase == .observing {
                saved.date = now
                saved.observedSeconds = max(0, saved.observedSeconds ?? 0)
                saved.habitatSeconds = saved.habitatSeconds ?? saved.seconds
            }
            saved.seconds = min(Self.maximumSeconds, saved.seconds)
            record = saved
        } else if let data = defaults.data(forKey: "originalMotivationGenerator.v1.dormancy"),
                  let old = try? JSONDecoder().decode(LegacyRecord.self, from: data),
                  old.restSeconds.isFinite, old.restSeconds >= 0 {
            let away = old.restingSince.map { max(0, now.timeIntervalSince($0)) } ?? 0
            record = Record(seconds: min(Self.maximumSeconds, old.restSeconds + away), date: now,
                            phase: .locked, seed: old.seed)
        } else {
            record = Record(seconds: 0, date: now, phase: .locked, seed: UInt64.random(in: 0...UInt64.max))
        }
        checkpoint(at: now)
    }

    var isObserving: Bool { record.phase == .observing }

    func seconds(at now: Date = .now) -> TimeInterval {
        let delta = max(0, now.timeIntervalSince(record.date))
        let rate: Double = isObserving ? (visibleScenes.isEmpty ? 0 : -Self.observationRate) : 1
        return min(Self.maximumSeconds, max(0, record.seconds + delta * rate))
    }

    static func growth(for seconds: TimeInterval) -> Double {
        min(maximumSeconds, max(0, seconds)) / maximumSeconds
    }

    func observationTime(at now: Date = .now) -> TimeInterval {
        guard isObserving else { return 0 }
        return (record.observedSeconds ?? 0) + (visibleScenes.isEmpty ? 0 : max(0, now.timeIntervalSince(record.date)))
    }

    var habitatSeconds: TimeInterval { record.habitatSeconds ?? record.seconds }

    func setVisible(_ visible: Bool, scene: UUID, at now: Date = .now) {
        guard visible != visibleScenes.contains(scene) else { return }
        checkpoint(at: now)
        if visible { visibleScenes.insert(scene) }
        else { visibleScenes.remove(scene) }
    }

    func observe(scene: UUID, at now: Date = .now) {
        guard !isObserving, visibleScenes.contains(scene) else { return }
        checkpoint(at: now)
        record.observedSeconds = 0
        record.habitatSeconds = record.seconds
        record.phase = .observing
        save()
    }

    func leave(at now: Date = .now) {
        guard isObserving else { return }
        checkpoint(at: now)
        record.phase = .locked
        record.observedSeconds = nil
        record.habitatSeconds = nil
        save()
    }

    func checkpoint(at now: Date = .now) {
        record = Record(seconds: seconds(at: now), date: now, phase: record.phase, seed: record.seed,
                        observedSeconds: isObserving ? observationTime(at: now) : nil,
                        habitatSeconds: record.habitatSeconds)
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(record) { defaults.set(data, forKey: key) }
    }
}
