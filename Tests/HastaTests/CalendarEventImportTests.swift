import Foundation
import Testing
@testable import Hasta

struct CalendarEventImportTests {
    private let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return calendar
    }()

    private func date(_ string: String, in identifier: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(identifier: identifier)!
        formatter.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime, .withDashSeparatorInDate]
        return formatter.date(from: string)!
    }

    @Test func importsAllDayYearlyEvent() throws {
        let ics = """
        BEGIN:VCALENDAR\r
        VERSION:2.0\r
        BEGIN:VEVENT\r
        DTSTART;VALUE=DATE:20270406\r
        RRULE:FREQ=YEARLY\r
        SUMMARY:Mom's Birthday\\, again\r
        BEGIN:VALARM\r
        DESCRIPTION:Reminder\r
        END:VALARM\r
        END:VEVENT\r
        END:VCALENDAR\r
        """
        let countdown = try #require(Countdown(ics: ics, calendar: calendar))
        #expect(countdown.title == "Mom's Birthday, again")
        #expect(countdown.isAllDay)
        #expect(countdown.repeatRule == .yearly)
        #expect(countdown.timeZoneIdentifier == "America/Los_Angeles")
        #expect(countdown.date == date("2027-04-06T00:00:00", in: "America/Los_Angeles"))
    }

    @Test func importsTimedEventInItsTimeZone() throws {
        let ics = """
        BEGIN:VCALENDAR
        BEGIN:VEVENT
        SUMMARY:Flight to
          Lisbon
        DTSTART;TZID=America/New_York:20261101T090000
        RRULE:FREQ=WEEKLY;INTERVAL=2
        END:VEVENT
        END:VCALENDAR
        """
        let countdown = try #require(Countdown(ics: ics, calendar: calendar))
        #expect(countdown.title == "Flight to Lisbon")
        #expect(!countdown.isAllDay)
        #expect(countdown.repeatRule == .never)
        #expect(countdown.date == date("2026-11-01T09:00:00", in: "America/New_York"))
    }

    @Test func importsUTCEventWithMonthlyRepeat() throws {
        let ics = "BEGIN:VEVENT\nDTSTART:20261215T180000Z\nRRULE:FREQ=MONTHLY;BYMONTHDAY=15\nSUMMARY:Rent\nEND:VEVENT"
        let countdown = try #require(Countdown(ics: ics, calendar: calendar))
        #expect(countdown.repeatRule == .monthly)
        #expect(countdown.date == date("2026-12-15T18:00:00", in: "UTC"))
    }

    @Test func rejectsFilesWithoutAnEvent() {
        #expect(Countdown(ics: "BEGIN:VCALENDAR\nEND:VCALENDAR", calendar: calendar) == nil)
        #expect(Countdown(ics: "BEGIN:VEVENT\nSUMMARY:No date\nEND:VEVENT", calendar: calendar) == nil)
    }
}
