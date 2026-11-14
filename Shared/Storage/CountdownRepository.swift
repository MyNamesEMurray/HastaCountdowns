import Foundation

enum CountdownRepository {
    static var fileURL: URL {
        AppGroup.containerURL.appending(path: "Countdowns.json")
    }

    static func load(from url: URL = CountdownRepository.fileURL) -> [Countdown] {
        guard let data = try? Data(contentsOf: url) else { return [] }
        do {
            return try decoder.decode([Countdown].self, from: data)
        } catch {
            try? data.write(to: url.deletingLastPathComponent().appending(path: "Countdowns.bad-\(Int(Date.now.timeIntervalSince1970)).json"), options: .atomic)
            return []
        }
    }

    static func save(_ countdowns: [Countdown], to url: URL = CountdownRepository.fileURL) throws {
        let data = try encoder.encode(countdowns)
        try data.write(to: url, options: .atomic)
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
