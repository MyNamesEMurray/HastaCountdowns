import SwiftUI

extension CountdownColor {
    var color: Color {
        switch self {
        case .red: .red
        case .orange: .orange
        case .yellow: .yellow
        case .green: .green
        case .mint: .mint
        case .teal: .teal
        case .cyan: .cyan
        case .blue: .blue
        case .indigo: .indigo
        case .purple: .purple
        case .pink: .pink
        case .brown: .brown
        case .graphite: Color(uiColor: .systemGray)
        }
    }
}

extension Countdown {
    var tint: Color {
        if let customColorHex, let custom = Color(hex: customColorHex) {
            return custom
        }
        return color.color
    }
}

extension Typeface {
    func font(size: CGFloat, weight: Font.Weight = .bold) -> Font {
        switch self {
        case .rounded: .system(size: size, weight: weight, design: .rounded)
        case .standard: .system(size: size, weight: weight, design: .default)
        case .serif: .system(size: size, weight: weight, design: .serif)
        case .mono: .system(size: size, weight: weight == .bold ? .semibold : weight, design: .monospaced)
        case .condensed: .system(size: size, weight: weight == .bold ? .heavy : weight).width(.condensed)
        }
    }

    func font(_ style: Font.TextStyle, weight: Font.Weight = .semibold) -> Font {
        switch self {
        case .rounded: .system(style, design: .rounded, weight: weight)
        case .standard: .system(style, design: .default, weight: weight)
        case .serif: .system(style, design: .serif, weight: weight)
        case .mono: .system(style, design: .monospaced, weight: weight)
        case .condensed: .system(style, design: .default, weight: weight).width(.condensed)
        }
    }
}

extension WidgetStyle {
    var usesLightForeground: Bool {
        self != .minimal && self != .paper
    }
}

extension GradientDirection {
    var points: (start: UnitPoint, end: UnitPoint) {
        switch self {
        case .vertical: (.top, .bottom)
        case .diagonal: (.topLeading, .bottomTrailing)
        case .horizontal: (.leading, .trailing)
        }
    }
}

extension CustomGradient {
    var colors: [Color] {
        [Color(hex: startHex) ?? .blue, Color(hex: endHex) ?? .purple]
    }

    var view: LinearGradient {
        LinearGradient(colors: colors, startPoint: direction.points.start, endPoint: direction.points.end)
    }

    var isBright: Bool {
        colors.map(\.luminance).reduce(0, +) / 2 > 0.6
    }

    static func starting(from tint: Color) -> CustomGradient {
        CustomGradient(
            startHex: tint.hexString ?? "#0A84FF",
            endHex: tint.shiftingHue(by: 0.12).adjusting(brightness: -0.15).hexString ?? "#5E5CE6"
        )
    }
}

extension Countdown {
    var usesDarkForeground: Bool {
        style == .paper || (style == .custom && customGradient?.isBright == true)
    }
}

extension Color {
    var luminance: Double {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        guard UIColor(self).getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return 0 }
        return 0.2126 * red + 0.7152 * green + 0.0722 * blue
    }

    init?(hex: String) {
        var string = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if string.hasPrefix("#") { string.removeFirst() }
        guard string.count == 6, let value = UInt64(string, radix: 16) else { return nil }
        self.init(
            .sRGB,
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }

    var hexString: String? {
        let resolved = UIColor(self).resolvedColor(with: UITraitCollection(userInterfaceStyle: .light))
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        guard resolved.getRed(&red, green: &green, blue: &blue, alpha: &alpha) else { return nil }
        func clamp(_ v: CGFloat) -> Int { Int((min(max(v, 0), 1) * 255).rounded()) }
        return String(format: "#%02X%02X%02X", clamp(red), clamp(green), clamp(blue))
    }
}
