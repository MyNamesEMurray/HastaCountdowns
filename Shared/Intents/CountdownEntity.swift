import AppIntents
import Foundation

struct CountdownEntity: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Countdown"
    static let defaultQuery = CountdownQuery()

    let id: UUID
    let title: String
    let subtitle: String
    let symbol: String

    init(_ countdown: Countdown, now: Date = .now) {
        id = countdown.id
        title = countdown.displayTitle
        subtitle = countdown.status(at: now).phrase
        symbol = countdown.symbol
    }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(title)",
            subtitle: "\(subtitle)",
            image: .init(systemName: symbol)
        )
    }
}

struct CountdownQuery: EntityQuery {
    func entities(for identifiers: [CountdownEntity.ID]) async throws -> [CountdownEntity] {
        let all = CountdownRepository.load()
        return identifiers.compactMap { id in
            all.first { $0.id == id }.map { CountdownEntity($0) }
        }
    }

    func suggestedEntities() async throws -> [CountdownEntity] {
        let all = CountdownRepository.load()
        return (all.upcoming() + all.past()).map { CountdownEntity($0) }
    }

    func defaultResult() async -> CountdownEntity? {
        CountdownRepository.load().upcoming().first.map { CountdownEntity($0) }
    }
}

struct SelectCountdownIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Select Countdown"
    static let description = IntentDescription("Choose which countdown this widget shows.")

    @Parameter(title: "Countdown")
    var countdown: CountdownEntity?

    init() {}

    init(countdown: CountdownEntity?) {
        self.countdown = countdown
    }
}
