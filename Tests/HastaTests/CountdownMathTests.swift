import Foundation
import Testing
@testable import Hasta

struct CountdownMathTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        return calendar
    }()

    private func date(_ string: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = calendar.timeZone
        formatter.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime, .withDashSeparatorInDate]
        return formatter.date(from: string)!
    }

    private var now: Date { date("2026-10-02T15:00:00") }

    @Test func countsDaysUntilEvent() {
        let countdown = Countdown(title: "Trip", date: date("2026-11-13T00:00:00"))
        let status = countdown.status(at: now, calendar: calendar)
        #expect(status.number == "42")
        #expect(status.phrase == "in 42 days")
        #expect(status.phase == .upcoming)
    }

    @Test func showsWeeksWithRemainder() {
        let countdown = Countdown(title: "Trip", date: date("2026-11-15T00:00:00"), unit: .weeks)
        #expect(countdown.status(at: now, calendar: calendar).phrase == "in 6 weeks, 2 days")
    }

    @Test func showsMonthsWithRemainder() {
        let countdown = Countdown(title: "Trip", date: date("2026-11-15T00:00:00"), unit: .months)
        #expect(countdown.status(at: now, calendar: calendar).phrase == "in 1 month, 13 days")
    }

    @Test func monthsFallBackToDaysWhenUnderAMonth() {
        let countdown = Countdown(title: "Soon", date: date("2026-10-05T00:00:00"), unit: .months)
        #expect(countdown.status(at: now, calendar: calendar).phrase == "in 3 days")
    }

    @Test func tomorrowAndToday() {
        let tomorrow = Countdown(title: "A", date: date("2026-10-03T00:00:00"))
        let today = Countdown(title: "B", date: date("2026-10-02T00:00:00"))
        #expect(tomorrow.status(at: now, calendar: calendar).phrase == "Tomorrow")
        #expect(today.status(at: now, calendar: calendar).phase == .today)
    }

    @Test func countsUpFromPastEvents() {
        let countdown = Countdown(title: "Past", date: date("2026-09-01T00:00:00"))
        let status = countdown.status(at: now, calendar: calendar)
        #expect(status.phase == .past)
        #expect(status.phrase == "31 days ago")
    }

    @Test func yearlyRepeatAdvancesToNextOccurrence() {
        let countdown = Countdown(title: "Birthday", date: date("1990-03-15T00:00:00"), repeatRule: .yearly)
        #expect(countdown.nextOccurrence(after: now, calendar: calendar) == date("2027-03-15T00:00:00"))
    }

    @Test func yearlyRepeatOnLeapDay() {
        let countdown = Countdown(title: "Leap", date: date("2024-02-29T00:00:00"), repeatRule: .yearly)
        #expect(countdown.nextOccurrence(after: now, calendar: calendar) == date("2027-02-28T00:00:00"))
    }

    @Test func monthlyRepeatKeepsEndOfMonth() {
        let countdown = Countdown(title: "Rent", date: date("2026-01-31T00:00:00"), repeatRule: .monthly)
        #expect(countdown.nextOccurrence(after: now, calendar: calendar) == date("2026-10-31T00:00:00"))
    }

    @Test func weeklyTimedRepeat() {
        let countdown = Countdown(title: "Class", date: date("2026-09-03T18:00:00"), isAllDay: false, repeatRule: .weekly)
        #expect(countdown.nextOccurrence(after: now, calendar: calendar) == date("2026-10-08T18:00:00"))
    }

    @Test func liveTimerForTimedEventLaterToday() {
        let countdown = Countdown(title: "Dinner", date: date("2026-10-02T19:00:00"), isAllDay: false)
        #expect(countdown.isLiveToday(at: now, calendar: calendar))
    }

    @Test func progressIsProportional() {
        let countdown = Countdown(title: "P", date: date("2026-10-12T00:00:00"), createdAt: date("2026-09-22T00:00:00"))
        #expect(countdown.progress(at: date("2026-10-02T00:00:00"), calendar: calendar) == 0.5)
    }

    @Test func premiumFeaturesAreStrippedWhenLocked() {
        let countdown = Countdown(title: "Fancy", customColorHex: "#123456", style: .vivid, typeface: .serif, backgroundImageID: "abc")
        let resolved = countdown.resolved(isPremium: false)
        #expect(resolved.style == .classic)
        #expect(resolved.typeface == .rounded)
        #expect(resolved.customColorHex == nil)
        #expect(resolved.backgroundImageID == nil)
        #expect(countdown.resolved(isPremium: true) == countdown)
    }

    @Test func decodesOlderDataWithMissingFields() throws {
        let json = #"[{"id":"7C9C3D5E-1C1F-4F55-9E2D-1A2B3C4D5E6F","date":800000000}]"#
        let decoded = try JSONDecoder().decode([Countdown].self, from: Data(json.utf8))
        #expect(decoded.count == 1)
        #expect(decoded[0].style == .classic)
    }
}
