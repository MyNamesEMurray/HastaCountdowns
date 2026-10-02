import SwiftUI
import UIKit

struct AppIconOption: Identifiable, Hashable {
    let id: String
    let title: String
    let iconName: String?
    let previewName: String

    static let all: [AppIconOption] = [
        AppIconOption(id: "default", title: "Sunrise", iconName: nil, previewName: "IconPreview-Default"),
        AppIconOption(id: "midnight", title: "Midnight", iconName: "AppIcon-Midnight", previewName: "IconPreview-Midnight"),
        AppIconOption(id: "ocean", title: "Ocean", iconName: "AppIcon-Ocean", previewName: "IconPreview-Ocean"),
        AppIconOption(id: "mint", title: "Mint", iconName: "AppIcon-Mint", previewName: "IconPreview-Mint"),
        AppIconOption(id: "mono", title: "Mono", iconName: "AppIcon-Mono", previewName: "IconPreview-Mono"),
    ]
}

struct AppIconPickerView: View {
    @Environment(PurchaseManager.self) private var purchases
    let onLocked: () -> Void
    @State private var currentIconName: String? = UIApplication.shared.alternateIconName

    var body: some View {
        List {
            Section {
                ForEach(AppIconOption.all) { option in
                    let isLocked = option.iconName != nil && !purchases.isPremium
                    let isSelected = option.iconName == currentIconName
                    Button {
                        select(option, isLocked: isLocked)
                    } label: {
                        HStack(spacing: 14) {
                            Image(option.previewName)
                                .resizable()
                                .frame(width: 60, height: 60)
                                .clipShape(.rect(cornerRadius: 13.5, style: .continuous))
                                .overlay {
                                    RoundedRectangle(cornerRadius: 13.5, style: .continuous)
                                        .strokeBorder(.quaternary, lineWidth: 0.5)
                                }
                            Text(option.title)
                                .foregroundStyle(.primary)
                            Spacer()
                            if isLocked {
                                Image(systemName: "lock.fill")
                                    .foregroundStyle(.secondary)
                            } else if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.body.weight(.semibold))
                                    .foregroundStyle(.tint)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .accessibilityAddTraits(isSelected ? .isSelected : [])
                }
            } footer: {
                if !purchases.isPremium {
                    Text("Alternate app icons are included with Hasta Premium.")
                }
            }
        }
        .navigationTitle("App Icon")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func select(_ option: AppIconOption, isLocked: Bool) {
        guard !isLocked else {
            onLocked()
            return
        }
        guard option.iconName != currentIconName, UIApplication.shared.supportsAlternateIcons else { return }
        Task {
            do {
                try await UIApplication.shared.setAlternateIconName(option.iconName)
                currentIconName = option.iconName
            } catch {
                currentIconName = UIApplication.shared.alternateIconName
            }
        }
    }
}
