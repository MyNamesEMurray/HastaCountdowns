import Foundation

enum CountdownRepository {
    static var fileURL: URL {
        AppGroup.containerURL.appending(path: "Countdowns.json")
    }

    static func load() -> [Countdown] {
        guard let data = try? Data(contentsOf: fileURL) else { return [] }
        return (try? decoder.decode([Countdown].self, from: data)) ?? []
    }

    static func save(_ countdowns: [Countdown]) throws {
        let data = try encoder.encode(countdowns)
        try data.write(to: fileURL, options: .atomic)
    }

    private static var encoder: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .secondsSince1970
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }

    private static var decoder: JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .secondsSince1970
        return decoder
    }
}
