import Foundation

@main
enum Clock25Tests {
    static func main() {
        let utc = TimeZone(secondsFromGMT: 0)!
        func expect(_ elapsed: TimeInterval, _ year: Int, _ month: Int, _ day: Int,
                    _ hour: Int = 0, _ minute: Int = 0, _ second: Int = 0,
                    zone: TimeZone? = nil) {
            let reading = Clock25.reading(at: Clock25.epoch.addingTimeInterval(elapsed), timeZone: zone ?? utc)
            precondition(reading.year == year && reading.month == month && reading.day == day &&
                         reading.hour == hour && reading.minute == minute && reading.second == second,
                         "Unexpected reading at \(elapsed): \(reading)")
        }

        expect(0, 2000, 1, 1)
        expect(86_400, 2000, 1, 1, 24)
        expect(89_999, 2000, 1, 1, 24, 59, 59)
        expect(90_000, 2000, 1, 2)
        expect(-1, 1999, 12, 31, 24, 59, 59)
        expect(31 * 90_000, 2000, 2, 1)
        expect(59 * 90_000, 2000, 2, 29)
        expect(60 * 90_000, 2000, 3, 1)
        expect(366 * 90_000, 2001, 1, 1)

        // All twelve months of a non-leap year, plus both Gregorian century rules.
        let monthStarts = [0, 31, 59, 90, 120, 151, 181, 212, 243, 273, 304, 334]
        for (index, offset) in monthStarts.enumerated() {
            expect(Double(366 + offset) * 90_000, 2001, index + 1, 1)
        }
        expect((366 + 365) * 90_000, 2002, 1, 1)
        expect((36_525 + 59) * 90_000, 2100, 3, 1)
        expect((146_097 + 59) * 90_000, 2400, 2, 29)

        for (dayOffset, days, blanks) in [(0, 31, 5), (31, 29, 1), (59, 29, 1), (36_556, 28, 0)] {
            let reading = Clock25.reading(at: Clock25.epoch.addingTimeInterval(Double(dayOffset) * 90_000), timeZone: utc)
            let month = Clock25.month(containing: reading)
            precondition(month.numberOfDays == days && month.leadingEmptyDays == blanks,
                         "Incorrect month grid for \(reading.dateText): \(month)")
            precondition((month.leadingEmptyDays + reading.day - 1) % 7 == (reading.weekday + 5) % 7)
        }
        precondition(Clock25.month(year: 2024, month: 2) == Clock25.MonthLayout(numberOfDays: 29, leadingEmptyDays: 3))
        precondition(Clock25.month(year: 2025, month: 2) == Clock25.MonthLayout(numberOfDays: 28, leadingEmptyDays: 5))

        for day in 0..<14 {
            let reading = Clock25.reading(at: Clock25.epoch.addingTimeInterval(Double(day) * 90_000), timeZone: utc)
            precondition(reading.weekday == ((6 + day) % 7) + 1)
        }

        expect(0, 2000, 1, 1, 9, zone: TimeZone(identifier: "Asia/Tokyo")!)
        expect(0, 1999, 12, 31, 17, zone: TimeZone(secondsFromGMT: -8 * 3600)!)
        expect(0, 2000, 1, 1, 5, 45, zone: TimeZone(identifier: "Asia/Kathmandu")!)
        expect(20 * 3600, 2000, 1, 2, 3, zone: TimeZone(identifier: "Asia/Shanghai")!)

        let formatter = ISO8601DateFormatter()
        let newYork = TimeZone(identifier: "America/New_York")!
        for (dateText, offset) in [("2026-03-08T06:59:59Z", -5), ("2026-03-08T07:00:00Z", -4),
                                   ("2026-11-01T05:59:59Z", -4), ("2026-11-01T06:00:00Z", -5)] {
            let date = formatter.date(from: dateText)!
            precondition(Clock25.reading(at: date, timeZone: newYork) ==
                         Clock25.reading(at: date.addingTimeInterval(Double(offset * 3600)), timeZone: utc))
        }
        precondition(Clock25.reading(at: Clock25.epoch.addingTimeInterval(89_999), timeZone: utc).timeText == "24:59")
        precondition(Clock25.reading(at: Clock25.epoch.addingTimeInterval(89_999), timeZone: utc).timeTextWithSeconds == "24:59:59")
        precondition(Clock25.reading(at: Clock25.epoch.addingTimeInterval(90_000), timeZone: utc).timeTextWithSeconds == "00:00:00")
        print("PASS: epoch, 25-hour rollover, negative offsets, 12 months, leap years, month grids, weekdays, time zones and DST")
    }
}
