import Foundation
import Combine

@MainActor
final class BreathStore: ObservableObject {
    struct Mark: Identifiable {
        let id: Int
        let duration: TimeInterval
    }
    @Published private(set) var marks: [Mark] = []
    var durations: [TimeInterval] { marks.map(\.duration) }
    @Published private(set) var beganAt: TimeInterval?
    private(set) var capacity = 60
    private var nextMarkID = 0

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
    }

    func cancel() { beganAt = nil }
    func discard() { beganAt = nil; marks = [] }

    func resize(capacity: Int) {
        self.capacity = min(512, max(1, capacity))
        trim()
    }

    private func trim() {
        if marks.count > capacity { marks.removeFirst(marks.count - capacity) }
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

@MainActor
final class DormancyStore: ObservableObject {
    enum Phase: String, Codable { case locked, observing }
    struct Record: Codable {
        var seconds: TimeInterval
        var date: Date
        var phase: Phase
        let seed: UInt64
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
            if saved.phase == .observing { saved.date = now }
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
        log1p(min(maximumSeconds, max(0, seconds)) / 30) / log1p(maximumSeconds / 30)
    }

    func setVisible(_ visible: Bool, scene: UUID, at now: Date = .now) {
        guard visible != visibleScenes.contains(scene) else { return }
        checkpoint(at: now)
        if visible { visibleScenes.insert(scene) }
        else { visibleScenes.remove(scene) }
    }

    func observe(scene: UUID, at now: Date = .now) {
        guard !isObserving, visibleScenes.contains(scene) else { return }
        checkpoint(at: now)
        record.phase = .observing
        save()
    }

    func leave(at now: Date = .now) {
        guard isObserving else { return }
        checkpoint(at: now)
        record.phase = .locked
        save()
    }

    func checkpoint(at now: Date = .now) {
        record = Record(seconds: seconds(at: now), date: now, phase: record.phase, seed: record.seed)
        save()
    }

    private func save() {
        if let data = try? JSONEncoder().encode(record) { defaults.set(data, forKey: key) }
    }
}
