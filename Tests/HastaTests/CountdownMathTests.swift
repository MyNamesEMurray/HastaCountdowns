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
        let countdown = Countdown(title: "Trip", date: date("2026-11-13T00:00:00"), unit: .days)
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
        let tomorrow = Countdown(title: "A", date: date("2026-10-03T00:00:00"), unit: .days)
        let today = Countdown(title: "B", date: date("2026-10-02T00:00:00"))
        #expect(tomorrow.status(at: now, calendar: calendar).phrase == "Tomorrow")
        #expect(today.status(at: now, calendar: calendar).phase == .today)
    }

    @Test func countsUpFromPastEvents() {
        let countdown = Countdown(title: "Past", date: date("2026-09-01T00:00:00"), unit: .days)
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

    @Test func autoPicksYearsForFarEvents() {
        let countdown = Countdown(title: "Far", date: date("2028-01-15T00:00:00"))
        #expect(countdown.status(at: now, calendar: calendar).phrase == "in 1 year, 3 months")
    }

    @Test func autoPicksMonths() {
        let countdown = Countdown(title: "Holidays", date: date("2026-12-20T00:00:00"))
        #expect(countdown.status(at: now, calendar: calendar).phrase == "in 2 months, 18 days")
    }

    @Test func autoPicksWeeks() {
        let countdown = Countdown(title: "Soon", date: date("2026-10-30T00:00:00"))
        #expect(countdown.status(at: now, calendar: calendar).phrase == "in 4 weeks")
    }

    @Test func autoPicksDays() {
        let countdown = Countdown(title: "Next week", date: date("2026-10-10T00:00:00"))
        #expect(countdown.status(at: now, calendar: calendar).phrase == "in 8 days")
    }

    @Test func autoPicksHoursForTimedEventsUnderADay() {
        let countdown = Countdown(title: "Flight", date: date("2026-10-03T09:30:00"), isAllDay: false)
        let status = countdown.status(at: now, calendar: calendar)
        #expect(status.phrase == "in 18 hours, 30 minutes")
        #expect(status.compactPhrase == "18h")
    }

    @Test func autoPicksMinutesForTimedEventsUnderAnHour() {
        let countdown = Countdown(title: "New Year", date: date("2026-10-03T00:15:00"), isAllDay: false)
        #expect(countdown.status(at: date("2026-10-02T23:30:00"), calendar: calendar).phrase == "in 45 minutes")
    }

    @Test func autoKeepsAllDayEventsInDays() {
        let countdown = Countdown(title: "Tomorrow", date: date("2026-10-03T00:00:00"))
        #expect(countdown.status(at: now, calendar: calendar).phrase == "Tomorrow")
    }

    @Test func yearsUnitFallsBackUnderAYear() {
        let countdown = Countdown(title: "Close", date: date("2026-12-20T00:00:00"), unit: .years)
        #expect(countdown.status(at: now, calendar: calendar).phrase == "in 2 months, 18 days")
    }

    @Test func reminderFireDatesForAllDayEvents() {
        let target = date("2026-10-20T00:00:00")
        let defaultTime = DateComponents(hour: 9, minute: 0)
        #expect(ReminderRule(amount: 0, unit: .days).fireDate(for: target, isAllDay: true, defaultTime: defaultTime, calendar: calendar) == date("2026-10-20T09:00:00"))
        #expect(ReminderRule(amount: 3, unit: .days, hour: 20, minute: 15).fireDate(for: target, isAllDay: true, defaultTime: defaultTime, calendar: calendar) == date("2026-10-17T20:15:00"))
        #expect(ReminderRule(amount: 2, unit: .weeks).fireDate(for: target, isAllDay: true, defaultTime: defaultTime, calendar: calendar) == date("2026-10-06T09:00:00"))
        #expect(ReminderRule(amount: 1, unit: .months).fireDate(for: target, isAllDay: true, defaultTime: defaultTime, calendar: calendar) == date("2026-09-20T09:00:00"))
    }

    @Test func reminderFireDatesForTimedEvents() {
        let target = date("2026-10-20T18:30:00")
        let defaultTime = DateComponents(hour: 9, minute: 0)
        #expect(ReminderRule(amount: 30, unit: .minutes).fireDate(for: target, isAllDay: false, defaultTime: defaultTime, calendar: calendar) == date("2026-10-20T18:00:00"))
        #expect(ReminderRule(amount: 2, unit: .hours).fireDate(for: target, isAllDay: false, defaultTime: defaultTime, calendar: calendar) == date("2026-10-20T16:30:00"))
        #expect(ReminderRule(amount: 1, unit: .days).fireDate(for: target, isAllDay: false, defaultTime: defaultTime, calendar: calendar) == date("2026-10-19T18:30:00"))
        #expect(ReminderRule(amount: 1, unit: .days, hour: 8, minute: 0).fireDate(for: target, isAllDay: false, defaultTime: defaultTime, calendar: calendar) == date("2026-10-19T08:00:00"))
    }

    @Test func reminderTitles() {
        let defaultTime = DateComponents(hour: 9, minute: 0)
        #expect(ReminderRule(amount: 0, unit: .minutes).title(isAllDay: false, defaultTime: defaultTime, calendar: calendar) == "At time of event")
        #expect(ReminderRule(amount: 15, unit: .minutes).title(isAllDay: false, defaultTime: defaultTime, calendar: calendar) == "15 minutes before")
        #expect(ReminderRule(amount: 1, unit: .weeks).title(isAllDay: false, defaultTime: defaultTime, calendar: calendar) == "1 week before")
        #expect(ReminderRule(amount: 1, unit: .days).title(isAllDay: true, defaultTime: defaultTime, calendar: calendar).hasPrefix("1 day before at 9:00"))
    }

    @Test func decodesLegacyReminders() throws {
        let json = #"[{"id":"7C9C3D5E-1C1F-4F55-9E2D-1A2B3C4D5E6F","date":800000000,"reminders":["weekBefore","dayOf"]}]"#
        let decoded = try JSONDecoder().decode([Countdown].self, from: Data(json.utf8))
        let rules = decoded[0].reminders
        #expect(rules.count == 2)
        #expect(rules[0].amount == 0 && rules[0].unit == .days)
        #expect(rules[1].amount == 1 && rules[1].unit == .weeks)
    }

    @Test func remindersRoundTrip() throws {
        let countdown = Countdown(title: "R", reminders: [ReminderRule(amount: 2, unit: .hours), ReminderRule(amount: 3, unit: .days, hour: 7, minute: 45)])
        let data = try JSONEncoder().encode(countdown)
        let decoded = try JSONDecoder().decode(Countdown.self, from: data)
        #expect(decoded.reminders == countdown.reminders)
    }
}
