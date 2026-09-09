import Foundation
import Combine

enum DeathClock {
    struct Profile: Codable, Equatable {
        let age: Int
        let expectancy: Int
        let startedAt: Date
        let timeZoneIdentifier: String

        var outcome: Outcome {
            if expectancy == 8000 { return .ancient }
            return expectancy < age ? .ghost : .countdown
        }

        var calendar: Calendar {
            var calendar = Calendar(identifier: .gregorian)
            calendar.timeZone = TimeZone(identifier: timeZoneIdentifier) ?? TimeZone(secondsFromGMT: 0)!
            return calendar
        }

        var deadline: Date {
            calendar.date(byAdding: .year, value: max(0, expectancy - age), to: startedAt) ?? startedAt
        }
    }

    enum Outcome { case ghost, ancient, countdown }

    struct Remaining: Equatable {
        let days: Int
        let weekends: Int
        let summers: Int
        let breakfasts: Int
        let books: Int
        let homecomings: Int

        var activities: String {
            [L("度过%ld个周末", weekends), L("享受%ld个夏天", summers), L("吃%ld顿早餐", breakfasts),
             L("读%ld本书", books), L("回%ld次老家", homecomings)].joined(separator: "、")
        }
    }

    static func remaining(for profile: Profile, at now: Date, southernHemisphere: Bool) -> Remaining {
        let end = profile.deadline
        let start = max(now, profile.startedAt)
        guard end > start else {
            return Remaining(days: 0, weekends: 0, summers: 0, breakfasts: 0, books: 0, homecomings: 0)
        }
        let seconds = end.timeIntervalSince(start)
        let days = Int(ceil(seconds / 86_400))
        let calendar = profile.calendar
        var saturday = calendar.startOfDay(for: start)
        let offset = (7 - calendar.component(.weekday, from: saturday)) % 7
        saturday = calendar.date(byAdding: .day, value: offset, to: saturday)!
        if saturday < start { saturday = calendar.date(byAdding: .day, value: 7, to: saturday)! }
        let weekends: Int
        if saturday >= end {
            weekends = 0
        } else {
            // Include Saturday starts in [start, end), including weeks crossing DST.
            let lastDay = calendar.startOfDay(for: end.addingTimeInterval(-0.001))
            weekends = calendar.dateComponents([.day], from: saturday, to: lastDay).day! / 7 + 1
        }

        let summerMonth = southernHemisphere ? 12 : 6
        let firstYear = calendar.component(.year, from: start)
        let lastYear = calendar.component(.year, from: end)
        var summers = 0
        for year in firstYear...lastYear {
            let summer = calendar.date(from: DateComponents(year: year, month: summerMonth, day: 1))!
            if summer >= start && summer < end { summers += 1 }
        }

        // Count complete calendar years and prorate the remainder against the next calendar year.
        // These frequencies are creative assumptions, not population statistics.
        let fullYears = calendar.dateComponents([.year], from: start, to: end).year!
        let anniversary = calendar.date(byAdding: .year, value: fullYears, to: start)!
        let followingAnniversary = calendar.date(byAdding: .year, value: 1, to: anniversary)!
        let years = Double(fullYears) + end.timeIntervalSince(anniversary) / followingAnniversary.timeIntervalSince(anniversary)
        return Remaining(days: days, weekends: weekends, summers: summers, breakfasts: days,
                         books: Int(floor(years * 12)), homecomings: Int(floor(years * 2)))
    }
}

@MainActor
final class DeathClockStore: ObservableObject {
    enum Stage { case age, expectancy, result }
    @Published var ageText = ""
    @Published var expectancy = 80
    @Published private(set) var profile: DeathClock.Profile?
    @Published private(set) var stage: Stage = .age
    @Published private(set) var contentVisible = true
    @Published private(set) var isTransitioning = false
    private let defaults: UserDefaults
    private let key = "originalMotivationGenerator.v1.deathClockProfile"
    private var transition: Task<Void, Never>?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        if let data = defaults.data(forKey: key),
           let saved = try? JSONDecoder().decode(DeathClock.Profile.self, from: data),
           (0...8000).contains(saved.age), (1...8000).contains(saved.expectancy) {
            profile = saved
            ageText = String(saved.age)
            expectancy = saved.expectancy
            stage = .result
        }
    }

    var age: Int? {
        guard let age = Int(ageText.trimmingCharacters(in: .whitespacesAndNewlines)),
              (0...8000).contains(age) else { return nil }
        return age
    }

    func confirmAge(reduceMotion: Bool) {
        guard age != nil, stage == .age else { return }
        changeStage(to: .expectancy, reduceMotion: reduceMotion)
    }

    func confirmExpectancy(reduceMotion: Bool, now: Date = .now, timeZone: TimeZone = .current) {
        guard let age, stage == .expectancy, (1...8000).contains(expectancy), !isTransitioning else { return }
        let profile = DeathClock.Profile(age: age, expectancy: expectancy, startedAt: now,
                                         timeZoneIdentifier: timeZone.identifier)
        guard let data = try? JSONEncoder().encode(profile) else { return }
        defaults.set(data, forKey: key)
        self.profile = profile
        changeStage(to: .result, reduceMotion: reduceMotion)
    }

    func startAgain() {
        transition?.cancel()
        profile = nil
        defaults.removeObject(forKey: key)
        stage = .age
        contentVisible = true
        isTransitioning = false
    }

    private func changeStage(to next: Stage, reduceMotion: Bool) {
        guard !isTransitioning else { return }
        guard !reduceMotion else { stage = next; return }
        isTransitioning = true
        contentVisible = false
        transition = Task { @MainActor in
            do {
                try await Task.sleep(nanoseconds: 300_000_000)
                stage = next
                try await Task.sleep(nanoseconds: 50_000_000)
                contentVisible = true
                try await Task.sleep(nanoseconds: 300_000_000)
                isTransitioning = false
            } catch { return }
        }
    }
}
