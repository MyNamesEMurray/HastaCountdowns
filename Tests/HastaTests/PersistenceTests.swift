import Foundation
import Testing
@testable import Hasta

struct PersistenceTests {
    private func tempDirectory() throws -> URL {
        let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString, directoryHint: .isDirectory)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        return url
    }

    @Test func repositoryRoundTrips() throws {
        let url = try tempDirectory().appending(path: "Countdowns.json")
        let countdown = Countdown(title: "Trip")
        try CountdownRepository.save([countdown], to: url)
        #expect(CountdownRepository.load(from: url).map(\.id) == [countdown.id])
    }

    @Test func corruptFileIsBackedUp() throws {
        let directory = try tempDirectory()
        let url = directory.appending(path: "Countdowns.json")
        let bad = Data(#"[{"title":"no id or date"}]"#.utf8)
        try bad.write(to: url)
        #expect(CountdownRepository.load(from: url).isEmpty)
        #expect(try Data(contentsOf: directory.appending(path: "Countdowns.bad.json")) == bad)
    }

    @Test func remindersAreCappedAtSixtySoonestFirst() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        let now = Date(timeIntervalSince1970: 1_790_000_000)
        let start = calendar.startOfDay(for: now)
        let countdowns = (0..<70).map { offset in
            Countdown(title: "C\(offset)", date: calendar.date(byAdding: .day, value: offset + 2, to: start)!)
        }
        let requests = ReminderScheduler.makeRequests(for: Array(countdowns.reversed()), now: now, calendar: calendar)
        #expect(requests.count == 60)
        #expect(requests.first?.identifier.contains(countdowns[0].id.uuidString) == true)
        #expect(requests.last?.identifier.contains(countdowns[59].id.uuidString) == true)
    }
}
