import SwiftUI

struct ColorPaletteView: View {
    @Binding var selection: CountdownColor
    @Binding var customHex: String?
    let isPremium: Bool
    let onLocked: () -> Void

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 10), count: 7)

    var body: some View {
        LazyVGrid(columns: columns, spacing: 12) {
            ForEach(CountdownColor.allCases) { color in
                let isSelected = customHex == nil && selection == color
                Button {
                    withAnimation(.snappy) {
                        selection = color
                        customHex = nil
                    }
                } label: {
                    Circle()
                        .fill(color.color.gradient)
                        .frame(width: 32, height: 32)
                        .overlay {
                            Circle()
                                .strokeBorder(Color(uiColor: .systemGray3), lineWidth: isSelected ? 3 : 0)
                                .padding(-5)
                        }
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(color.title)
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
            customColorButton
        }
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var customColorButton: some View {
        let isSelected = customHex != nil
        if isPremium {
            ColorPicker(
                selection: Binding(
                    get: { customHex.flatMap { Color(hex: $0) } ?? selection.color },
                    set: { customHex = $0.hexString }
                ),
                supportsOpacity: false
            ) {
                EmptyView()
            }
            .labelsHidden()
            .frame(width: 32, height: 32)
            .overlay {
                Circle()
                    .strokeBorder(Color(uiColor: .systemGray3), lineWidth: isSelected ? 3 : 0)
                    .padding(-5)
                    .allowsHitTesting(false)
            }
            .frame(maxWidth: .infinity)
            .accessibilityLabel("Custom Color")
        } else {
            Button(action: onLocked) {
                Circle()
                    .fill(AngularGradient(colors: [.red, .yellow, .green, .cyan, .blue, .purple, .red], center: .center))
                    .frame(width: 32, height: 32)
                    .overlay {
                        Image(systemName: "lock.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .shadow(radius: 1)
                    }
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Custom Color, Premium")
        }
    }
}
