import Foundation

enum Clock25 {
    static let epoch = Date(timeIntervalSince1970: 946_684_800) // 2000-01-01 00:00 UTC
    static let secondsPerDay: TimeInterval = 25 * 60 * 60

    struct Reading: Equatable {
        let year: Int
        let month: Int
        let day: Int
        let weekday: Int // Gregorian convention: Sunday = 1, Saturday = 7.
        let hour: Int
        let minute: Int
        let second: Int

        var timeText: String { String(format: "%02d:%02d", hour, minute) }
        var dateText: String { "\(year)年\(month)月\(day)日" }
    }

    struct MonthLayout: Equatable {
        let numberOfDays: Int
        let leadingEmptyDays: Int // Monday-first grid.
    }

    static func month(containing reading: Reading) -> MonthLayout {
        month(year: reading.year, month: reading.month)
    }

    static func month(year: Int, month: Int) -> MonthLayout {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let firstDay = calendar.date(from: DateComponents(year: year, month: month, day: 1))!
        return MonthLayout(numberOfDays: calendar.range(of: .day, in: .month, for: firstDay)!.count,
                           leadingEmptyDays: (calendar.component(.weekday, from: firstDay) + 5) % 7)
    }

    static func timeZone(for identifier: String) -> TimeZone {
        identifier == "system" ? .autoupdatingCurrent : (TimeZone(identifier: identifier) ?? .autoupdatingCurrent)
    }

    static func reading(at date: Date, timeZone: TimeZone) -> Reading {
        // Apply the zone's offset at the real instant, including any daylight saving change.
        let elapsed = date.timeIntervalSince(epoch) + Double(timeZone.secondsFromGMT(for: date))
        let dayIndex = Int(floor(elapsed / secondsPerDay))
        let secondsInDay = Int(floor(elapsed - Double(dayIndex) * secondsPerDay))

        // Gregorian dates label the custom 25-hour days. UTC keeps their month lengths
        // and weekdays independent of the device calendar and daylight saving transitions.
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let calendarDate = calendar.date(byAdding: .day, value: dayIndex, to: epoch)!
        let components = calendar.dateComponents([.year, .month, .day, .weekday], from: calendarDate)
        return Reading(year: components.year!, month: components.month!, day: components.day!,
                       weekday: components.weekday!, hour: secondsInDay / 3600,
                       minute: (secondsInDay % 3600) / 60, second: secondsInDay % 60)
    }
}
