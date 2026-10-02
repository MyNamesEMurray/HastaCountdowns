import Foundation

enum AppGroup {
    static let identifier = "group.com.exaltedpixels.Hasta"

    static var containerURL: URL {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: identifier) ?? URL.documentsDirectory
    }

    static var defaults: UserDefaults {
        UserDefaults(suiteName: identifier) ?? .standard
    }
}

enum Premium {
    static let productID = "com.exaltedpixels.Hasta.premium"
    private static let key = "premiumUnlocked"

    static var isUnlocked: Bool {
        get { AppGroup.defaults.bool(forKey: key) }
        set { AppGroup.defaults.set(newValue, forKey: key) }
    }
}

enum ReminderPreferences {
    private static let hourKey = "reminderHour"
    private static let minuteKey = "reminderMinute"

    static var time: DateComponents {
        get {
            let defaults = AppGroup.defaults
            let hour = defaults.object(forKey: hourKey) as? Int ?? 9
            let minute = defaults.object(forKey: minuteKey) as? Int ?? 0
            return DateComponents(hour: hour, minute: minute)
        }
        set {
            AppGroup.defaults.set(newValue.hour ?? 9, forKey: hourKey)
            AppGroup.defaults.set(newValue.minute ?? 0, forKey: minuteKey)
        }
    }
}

enum DeepLink {
    static let scheme = "hasta"

    static func countdown(_ id: UUID) -> URL {
        URL(string: "\(scheme)://countdown/\(id.uuidString)")!
    }

    static let newCountdown = URL(string: "\(scheme)://new")!

    enum Destination: Equatable {
        case countdown(UUID)
        case newCountdown
    }

    static func destination(for url: URL) -> Destination? {
        guard url.scheme == scheme else { return nil }
        switch url.host() {
        case "countdown":
            guard let id = UUID(uuidString: url.lastPathComponent) else { return nil }
            return .countdown(id)
        case "new":
            return .newCountdown
        default:
            return nil
        }
    }
}
