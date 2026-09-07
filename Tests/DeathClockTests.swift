import Foundation

@main
@MainActor
enum DeathClockTests {
    static func main() throws {
        let parser = ISO8601DateFormatter()
        let start = parser.date(from: "2025-01-01T00:00:00Z")!
        func profile(_ age: Int, _ expectancy: Int, _ date: Date = start) -> DeathClock.Profile {
            DeathClock.Profile(age: age, expectancy: expectancy, startedAt: date, timeZoneIdentifier: "GMT")
        }
        precondition(profile(40, 39).outcome == .ghost)
        precondition(profile(8000, 8000).outcome == .ancient)
        precondition(profile(40, 40).outcome == .countdown)
        let zero = DeathClock.remaining(for: profile(40, 40), at: start, southernHemisphere: true)
        precondition(zero.days == 0 && zero.books == 0 && zero.homecomings == 0)
        let oneYear = profile(25, 26)
        let count = DeathClock.remaining(for: oneYear, at: start, southernHemisphere: true)
        precondition(count == DeathClock.Remaining(days: 365, weekends: 52, summers: 1, breakfasts: 365, books: 12, homecomings: 2))
        precondition(count.activities.contains("回2次老家"))
        let expired = DeathClock.remaining(for: oneYear, at: start.addingTimeInterval(400 * 86_400), southernHemisphere: false)
        precondition(expired.days == 0 && expired.weekends == 0 && expired.summers == 0)
        let leapStart = parser.date(from: "2024-01-01T00:00:00Z")!
        precondition(DeathClock.remaining(for: profile(0, 1, leapStart), at: leapStart, southernHemisphere: false).days == 366)
        let october = parser.date(from: "2025-10-01T00:00:00Z")!
        precondition(DeathClock.remaining(for: oneYear, at: october, southernHemisphere: true).summers == 1)
        precondition(DeathClock.remaining(for: oneYear, at: october, southernHemisphere: false).summers == 0)
        let distant = DeathClock.remaining(for: profile(0, 7999), at: start, southernHemisphere: true)
        precondition(distant.days > 2_900_000 && distant.summers == 7999)

        let suite = "omg-death-tests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = DeathClockStore(defaults: defaults)
        store.ageText = "abc"
        store.confirmAge(reduceMotion: true)
        precondition(store.stage == .age)
        store.ageText = "25"
        store.confirmAge(reduceMotion: true)
        precondition(store.stage == .expectancy)
        store.expectancy = 8001
        store.confirmExpectancy(reduceMotion: true)
        precondition(store.profile == nil)
        store.expectancy = 8000
        store.confirmExpectancy(reduceMotion: true, now: start, timeZone: TimeZone(secondsFromGMT: 0)!)
        precondition(store.stage == .result && store.profile?.outcome == .ancient)
        let restored = DeathClockStore(defaults: defaults)
        precondition(restored.profile == store.profile && restored.stage == .result)
        restored.startAgain()
        precondition(restored.stage == .age && DeathClockStore(defaults: defaults).profile == nil)
        print("PASS: death-clock branches, zero/expired life, leap years, seasons, 7999 years, validation and persistence")
    }
}
