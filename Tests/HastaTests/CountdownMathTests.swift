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

    @Test func everyOtherWeekRepeat() {
        let countdown = Countdown(title: "Class", date: date("2026-09-03T18:00:00"), isAllDay: false, repeatRule: RepeatRule(frequency: .weekly, interval: 2))
        #expect(countdown.nextOccurrence(after: now, calendar: calendar) == date("2026-10-15T18:00:00"))
    }

    @Test func weeklyRepeatOnSpecificDays() {
        let countdown = Countdown(title: "Gym", date: date("2026-09-01T00:00:00"), repeatRule: RepeatRule(frequency: .weekly, weekdays: [3, 5]))
        #expect(countdown.nextOccurrence(after: now, calendar: calendar) == date("2026-10-06T00:00:00"))
        var biweekly = countdown
        biweekly.repeatRule.interval = 2
        #expect(biweekly.nextOccurrence(after: now, calendar: calendar) == date("2026-10-13T00:00:00"))
    }

    @Test func monthlyRepeatOnOrdinalWeekday() {
        let third = Countdown(title: "Book club", date: date("2026-01-15T19:00:00"), isAllDay: false, repeatRule: RepeatRule(frequency: .monthly, ordinalWeekday: .init(ordinal: 3, weekday: 5)))
        #expect(third.nextOccurrence(after: now, calendar: calendar) == date("2026-10-15T19:00:00"))
        let last = Countdown(title: "Payday", date: date("2026-01-30T00:00:00"), repeatRule: RepeatRule(frequency: .monthly, ordinalWeekday: .init(ordinal: -1, weekday: 6)))
        #expect(last.nextOccurrence(after: now, calendar: calendar) == date("2026-10-30T00:00:00"))
    }

    @Test func everyThirdDayRepeat() {
        let countdown = Countdown(title: "Water plants", date: date("2026-09-01T00:00:00"), repeatRule: RepeatRule(frequency: .daily, interval: 3))
        #expect(countdown.nextOccurrence(after: now, calendar: calendar) == date("2026-10-04T00:00:00"))
    }

    @Test func describesCustomRepeats() {
        #expect(RepeatRule(frequency: .weekly, interval: 2).title == "Every 2 weeks")
        #expect(RepeatRule(frequency: .monthly, ordinalWeekday: .init(ordinal: 3, weekday: 5)).title == "Every Month on the third Thursday")
        #expect(RepeatRule(frequency: .daily, interval: 3).sentence == "Repeats every 3 days")
    }

    @Test func repeatRulesStayReadableByOlderVersions() throws {
        let encoder = JSONEncoder()
        #expect(String(data: try encoder.encode(RepeatRule.yearly), encoding: .utf8) == "\"yearly\"")
        #expect(String(data: try encoder.encode(RepeatRule.never), encoding: .utf8) == "\"never\"")
        let custom = RepeatRule(frequency: .monthly, ordinalWeekday: .init(ordinal: 3, weekday: 5))
        #expect(try JSONDecoder().decode(RepeatRule.self, from: encoder.encode(custom)) == custom)
        #expect(try JSONDecoder().decode(RepeatRule.self, from: Data("\"weekly\"".utf8)) == .weekly)
    }

    @Test func timedEventJustPassedCountsUpInsteadOfZeroSegments() {
        let countdown = Countdown(title: "Dinner", date: date("2026-10-02T14:30:00"), isAllDay: false)
        #expect(countdown.segments(at: now, calendar: calendar).isEmpty)
        #expect(countdown.isSinceToday(at: now, calendar: calendar))
        #expect(!countdown.isSinceToday(at: date("2026-10-03T15:00:00"), calendar: calendar))
    }

    @Test func liveTimerForTimedEventLaterToday() {
        let countdown = Countdown(title: "Dinner", date: date("2026-10-02T19:00:00"), isAllDay: false)
        #expect(countdown.isLiveToday(at: now, calendar: calendar))
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

    @Test func newStylesAndProgressAreStrippedWhenLocked() {
        for style in [WidgetStyle.glass, .gradient, .paper] {
            let countdown = Countdown(title: "Styled", style: style, showsProgress: true)
            let resolved = countdown.resolved(isPremium: false)
            #expect(resolved.style == .classic)
            #expect(!resolved.showsProgress)
        }
    }

    @Test func slideshowAndSinceLabelAreStrippedWhenLocked() {
        let countdown = Countdown(title: "Us", backgroundImageID: "a", extraBackgroundImageIDs: ["b", "c"], sinceLabel: "Together")
        #expect(countdown.allBackgroundImageIDs == ["a", "b", "c"])
        let resolved = countdown.resolved(isPremium: false)
        #expect(resolved.allBackgroundImageIDs.isEmpty)
        #expect(resolved.sinceLabel.isEmpty)
    }

    @Test func subtitleUsesSinceLabelOnlyWhenPast() {
        let countdown = Countdown(title: "Us", date: date("2026-09-02T00:00:00"), sinceLabel: " Together ")
        let past = countdown.status(at: now, calendar: calendar)
        #expect(countdown.subtitle(status: past, at: now, style: .abbreviated).hasPrefix("Together · "))
        let future = Countdown(title: "Us", date: date("2026-12-02T00:00:00"), sinceLabel: "Together")
        #expect(!future.subtitle(status: future.status(at: now, calendar: calendar), at: now, style: .abbreviated).contains("Together"))
    }

    @Test func liveActivitiesPickSoonestWithinWindow() {
        let soon = Countdown(title: "Soon", date: now.addingTimeInterval(3_600), isAllDay: false)
        let later = Countdown(title: "Later", date: now.addingTimeInterval(7_200), isAllDay: false)
        let far = Countdown(title: "Far", date: now.addingTimeInterval(86_400), isAllDay: false)
        let past = Countdown(title: "Past", date: now.addingTimeInterval(-60), isAllDay: false)
        let due = LiveActivityManager.due([far, later, past, soon], now: now, window: 8 * 3_600)
        #expect(due.map(\.0.title) == ["Soon", "Later"])
    }

    @Test func slideshowIndexAdvancesEveryHour() {
        let base = Date(timeIntervalSince1970: 1_790_000_000)
        let hourStart = Date(timeIntervalSince1970: Double(Int(base.timeIntervalSince1970 / 3_600) * 3_600))
        #expect(Countdown.slideshowIndex(at: hourStart.addingTimeInterval(3_599), count: 3) == Countdown.slideshowIndex(at: hourStart, count: 3))
        #expect(Countdown.slideshowIndex(at: hourStart.addingTimeInterval(3_600), count: 3) == (Countdown.slideshowIndex(at: hourStart, count: 3) + 1) % 3)
        #expect(Countdown.slideshowIndex(at: base, count: 1) == 0)
    }

    @Test func eachSlideshowPhotoKeepsItsOwnFraming() {
        var countdown = Countdown(title: "Us")
        countdown.setBackgrounds(["a", "b", "c"])
        let zoomed = BackgroundFraming(focusX: 0.2, focusY: 0.3, zoom: 2)
        countdown.setFraming(zoomed, for: "a")
        countdown.setFraming(zoomed, for: "c")
        #expect(countdown.framing(for: "a") == zoomed)
        #expect(countdown.framing(for: "b") == nil)
        #expect(countdown.framing(for: "c") == zoomed)
        countdown.removeBackground("a")
        #expect(countdown.backgroundImageID == "b")
        #expect(countdown.extraBackgroundImageIDs == ["c"])
        #expect(countdown.framing(for: "c") == zoomed)
        countdown.removeBackground("c")
        countdown.removeBackground("b")
        #expect(countdown.allBackgroundImageIDs.isEmpty)
    }

    @Test func oldRecordsKeepNewFieldsFromLocalCopy() {
        let local = Countdown(title: "Us", extraBackgroundImageIDs: ["b"], showsProgress: true, sinceLabel: "Together")
        var remote = Countdown(id: local.id, title: "Us edited")
        remote.keepNewFields(from: local)
        #expect(remote.extraBackgroundImageIDs == ["b"])
        #expect(remote.showsProgress)
        #expect(remote.sinceLabel == "Together")
        #expect(local.backgroundImageSlots.count == 5)
    }

    @Test func liveActivityOverrideBeatsGlobalSetting() {
        var countdown = Countdown(title: "T")
        #expect(countdown.startsLiveActivity(globalEnabled: true))
        #expect(!countdown.startsLiveActivity(globalEnabled: false))
        countdown.liveActivity = .on
        #expect(countdown.startsLiveActivity(globalEnabled: false))
        countdown.liveActivity = .off
        #expect(!countdown.startsLiveActivity(globalEnabled: true))
        var remote = Countdown(id: countdown.id, title: "T")
        remote.keepNewFields(from: countdown)
        #expect(remote.liveActivity == .off)
    }

    @Test func liveActivityToggleFollowsGlobalUntilChanged() {
        var countdown = Countdown(title: "T")
        countdown.setLiveActivity(true, globalEnabled: true)
        #expect(countdown.liveActivity == .automatic)
        countdown.setLiveActivity(false, globalEnabled: true)
        #expect(countdown.liveActivity == .off)
        countdown.setLiveActivity(true, globalEnabled: false)
        #expect(countdown.liveActivity == .on)
        countdown.setLiveActivity(false, globalEnabled: false)
        #expect(countdown.liveActivity == .automatic)
    }

    @Test func pushScheduleOnlyIncludesEnabledUpcomingCountdowns() {
        let soon = Countdown(title: "Soon", date: now.addingTimeInterval(7_200), isAllDay: false)
        var off = Countdown(title: "Off", date: now.addingTimeInterval(3_600), isAllDay: false)
        off.liveActivity = .off
        let past = Countdown(title: "Past", date: now.addingTimeInterval(-60), isAllDay: false)
        let far = Countdown(title: "Far", date: now.addingTimeInterval(60 * 86_400), isAllDay: false)
        let items = LiveActivityPushService.scheduleItems([far, past, off, soon], now: now, globalEnabled: true, leadHours: 2)
        #expect(items.map { $0.id } == [soon.id])
        #expect(items[0].fireAt == items[0].target - 7_200)
        #expect(LiveActivityPushService.scheduleItems([soon], now: now, globalEnabled: false, leadHours: 2).isEmpty)
    }

    @Test func liveActivityStateUsesEpochSeconds() throws {
        let state = CountdownActivityAttributes.ContentState(start: Date(timeIntervalSince1970: 100), target: Date(timeIntervalSince1970: 200), revision: 5)
        let json = String(data: try JSONEncoder().encode(state), encoding: .utf8) ?? ""
        #expect(json.contains("\"target\":200"))
        #expect(!json.contains("title"))
        #expect(try JSONDecoder().decode(CountdownActivityAttributes.ContentState.self, from: Data(#"{"start":1,"target":2}"#.utf8)).revision == 0)
        #expect(try JSONDecoder().decode(CountdownActivityAttributes.ContentState.self, from: Data(json.utf8)) == state)
    }

    @Test func progressStyleDefaultsToBarAndSurvivesOldData() throws {
        #expect(Countdown(title: "T").progressStyle == .bar)
        let json = #"[{"id":"7C9C3D5E-1C1F-4F55-9E2D-1A2B3C4D5E6F","date":800000000,"progressStyle":"ring"}]"#
        #expect(try JSONDecoder().decode([Countdown].self, from: Data(json.utf8)).first?.progressStyle == .ring)
        let bad = #"[{"id":"7C9C3D5E-1C1F-4F55-9E2D-1A2B3C4D5E6F","date":800000000,"progressStyle":"pie"}]"#
        #expect(try JSONDecoder().decode([Countdown].self, from: Data(bad.utf8)).first?.progressStyle == .bar)
    }

    @Test func customGradientIsStrippedWhenLockedAndPicksReadableText() throws {
        let gradient = CustomGradient(startHex: "#FFFFFF", endHex: "#F0F0F0")
        let countdown = Countdown(title: "T", style: .custom, customGradient: gradient)
        let resolved = countdown.resolved(isPremium: false)
        #expect(resolved.style == .classic)
        #expect(resolved.customGradient == nil)
        #expect(countdown.usesDarkForeground)
        let dark = Countdown(title: "T", style: .custom, customGradient: CustomGradient(startHex: "#101010", endHex: "#303030"))
        #expect(!dark.usesDarkForeground)
        let decoded = try JSONDecoder().decode([Countdown].self, from: JSONEncoder().encode([countdown]))
        #expect(decoded.first?.customGradient == gradient)
        let bad = #"[{"id":"7C9C3D5E-1C1F-4F55-9E2D-1A2B3C4D5E6F","date":800000000,"customGradient":{"startHex":"#000000"}}]"#
        #expect(try JSONDecoder().decode([Countdown].self, from: Data(bad.utf8)).first?.customGradient == nil)
    }

    @Test func progressTracksElapsedShare() {
        let countdown = Countdown(
            title: "Term",
            date: date("2026-10-12T00:00:00"),
            showsProgress: true,
            createdAt: date("2026-09-22T00:00:00")
        )
        let fraction = countdown.progress(at: date("2026-10-02T00:00:00"), calendar: calendar)
        #expect(fraction == 0.5)
        #expect(countdown.progress(at: date("2026-11-01T00:00:00"), calendar: calendar) == 1)
        var repeating = countdown
        repeating.repeatRule = .yearly
        #expect(repeating.progress(at: now, calendar: calendar) == nil)
        var off = countdown
        off.showsProgress = false
        #expect(off.progress(at: now, calendar: calendar) == nil)
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

    @Test func timedEventsCountElapsedDays() {
        let countdown = Countdown(title: "Party", date: date("2027-01-09T01:00:00"), isAllDay: false, unit: .days)
        #expect(countdown.status(at: date("2026-10-02T14:48:00"), calendar: calendar).number == "98")
    }

    @Test func timedEventTomorrowStillReadsTomorrowInDays() {
        let countdown = Countdown(title: "Breakfast", date: date("2026-10-03T08:00:00"), isAllDay: false, unit: .days)
        #expect(countdown.status(at: now, calendar: calendar).phrase == "Tomorrow")
    }

    @Test func framingCenteredFillsSquareFromLandscape() {
        let rect = BackgroundFraming.centered.visibleRect(imageSize: CGSize(width: 2000, height: 1000), containerSize: CGSize(width: 100, height: 100))
        #expect(abs(rect.width - 0.5) < 0.0001)
        #expect(abs(rect.height - 1) < 0.0001)
        #expect(abs(rect.minX - 0.25) < 0.0001)
    }

    @Test func framingZoomAndFocusStayInBounds() {
        let framing = BackgroundFraming(focusX: 0.95, focusY: 0.05, zoom: 2)
        let rect = framing.visibleRect(imageSize: CGSize(width: 1000, height: 1000), containerSize: CGSize(width: 200, height: 100))
        #expect(abs(rect.width - 0.5) < 0.0001)
        #expect(abs(rect.height - 0.25) < 0.0001)
        #expect(abs(rect.maxX - 1) < 0.0001)
        #expect(abs(rect.minY) < 0.0001)
    }

    @Test func framingPanMovesOppositeToDrag() {
        let image = CGSize(width: 1000, height: 1000)
        let container = CGSize(width: 100, height: 100)
        let zoomed = BackgroundFraming(zoom: 2)
        let panned = zoomed.panned(by: CGSize(width: 50, height: 0), imageSize: image, containerSize: container)
        #expect(panned.focusX < zoomed.focusX)
        #expect(abs(panned.focusX - 0.25) < 0.0001)
    }

    @Test func framingDecodesWhenMissing() throws {
        let json = #"{"id":"7C9C3D5E-1C1F-4F55-9E2D-1A2B3C4D5E6F","date":800000000}"#
        let decoded = try JSONDecoder().decode(Countdown.self, from: Data(json.utf8))
        #expect(decoded.backgroundFraming == nil)
    }

    @Test func segmentsForFarEventsUseYearsMonthsDays() {
        let countdown = Countdown(title: "Far", date: date("2028-01-15T00:00:00"))
        #expect(countdown.segments(at: now, calendar: calendar) == [
            CountdownSegment(value: 1, label: "year"),
            CountdownSegment(value: 3, label: "months"),
            CountdownSegment(value: 12, label: "days"),
        ])
    }

    @Test func segmentsForMonthsAwayIncludeHours() {
        let countdown = Countdown(title: "Party", date: date("2027-01-02T18:00:00"), isAllDay: false)
        #expect(countdown.segments(at: now, calendar: calendar) == [
            CountdownSegment(value: 3, label: "months"),
            CountdownSegment(value: 0, label: "days"),
            CountdownSegment(value: 3, label: "hours"),
        ])
    }

    @Test func segmentsForDaysAwayUseDaysAndHours() {
        let countdown = Countdown(title: "Soon", date: date("2026-10-05T00:00:00"))
        #expect(countdown.segments(at: now, calendar: calendar) == [
            CountdownSegment(value: 2, label: "days"),
            CountdownSegment(value: 9, label: "hours"),
        ])
    }

    @Test func segmentsAreEmptyForTimedEventsUnderADay() {
        let countdown = Countdown(title: "Dinner", date: date("2026-10-02T19:00:00"), isAllDay: false)
        #expect(countdown.segments(at: now, calendar: calendar).isEmpty)
    }

    private func calendar(_ identifier: String) -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: identifier)!
        return calendar
    }

    private func date(_ string: String, in identifier: String) -> Date {
        let formatter = ISO8601DateFormatter()
        formatter.timeZone = TimeZone(identifier: identifier)!
        formatter.formatOptions = [.withFullDate, .withTime, .withColonSeparatorInTime, .withDashSeparatorInDate]
        return formatter.date(from: string)!
    }

    @Test func allDayDateStaysTheSameDayWhenTravelingWest() {
        let created = Countdown(title: "Birthday", date: date("2027-04-06T00:00:00", in: "America/New_York"), timeZoneIdentifier: "America/New_York")
        let losAngeles = calendar("America/Los_Angeles")
        let now = date("2026-10-02T15:00:00", in: "America/Los_Angeles")
        #expect(created.nextOccurrence(after: now, calendar: losAngeles) == date("2027-04-06T00:00:00", in: "America/Los_Angeles"))
        #expect(created.status(at: now, calendar: losAngeles).days == 186)
    }

    @Test func allDayDateStaysTheSameDayWhenTravelingEast() {
        let created = Countdown(title: "Trip", date: date("2026-12-24T00:00:00", in: "America/Los_Angeles"), timeZoneIdentifier: "America/Los_Angeles")
        let tokyo = calendar("Asia/Tokyo")
        let now = date("2026-10-03T08:00:00", in: "Asia/Tokyo")
        #expect(created.nextOccurrence(after: now, calendar: tokyo) == date("2026-12-24T00:00:00", in: "Asia/Tokyo"))
    }

    @Test func timedEventsStayAtTheSameMomentAcrossTimeZones() {
        let flight = Countdown(title: "Flight", date: date("2026-11-01T09:00:00", in: "America/New_York"), isAllDay: false, timeZoneIdentifier: "America/New_York")
        let losAngeles = calendar("America/Los_Angeles")
        let now = date("2026-10-02T12:00:00", in: "America/Los_Angeles")
        #expect(flight.nextOccurrence(after: now, calendar: losAngeles) == date("2026-11-01T06:00:00", in: "America/Los_Angeles"))
    }

    @Test func timedDaysCountAcrossSpringForward() {
        let newYork = calendar("America/New_York")
        let countdown = Countdown(title: "Meeting", date: date("2027-03-11T09:00:00", in: "America/New_York"), isAllDay: false, unit: .days)
        #expect(countdown.status(at: date("2027-03-01T09:00:00", in: "America/New_York"), calendar: newYork).number == "10")
    }

    @Test func adoptingTimeZoneKeepsTheCalendarDay() {
        var countdown = Countdown(title: "Holiday", date: date("2026-12-25T00:00:00", in: "Europe/London"), timeZoneIdentifier: "Europe/London")
        let losAngeles = calendar("America/Los_Angeles")
        countdown.adoptCurrentTimeZone(calendar: losAngeles)
        #expect(countdown.timeZoneIdentifier == "America/Los_Angeles")
        #expect(countdown.date == date("2026-12-25T00:00:00", in: "America/Los_Angeles"))
    }

    @Test func timedReminderTriggersArePinnedToATimeZone() {
        let newYork = calendar("America/New_York")
        let fire = date("2026-10-20T18:00:00", in: "America/New_York")
        let timed = ReminderRule.triggerComponents(for: fire, isAllDay: false, calendar: newYork)
        let allDay = ReminderRule.triggerComponents(for: fire, isAllDay: true, calendar: newYork)
        #expect(timed.timeZone == TimeZone(identifier: "America/New_York"))
        #expect(timed.hour == 18)
        #expect(allDay.timeZone == nil)
        #expect(allDay.hour == 18)
    }
}
