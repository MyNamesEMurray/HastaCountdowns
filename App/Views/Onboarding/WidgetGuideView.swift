import SwiftUI

struct WidgetGuideView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            WidgetGuideContent()
                .navigationTitle("Add Widgets")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                            .fontWeight(.semibold)
                    }
                }
        }
        .presentationDetents([.medium, .large])
    }
}

struct WidgetGuideContent: View {
    var body: some View {
        List {
            Section {
                step(1, "Touch and hold an empty area of your Home Screen until the apps jiggle.")
                step(2, "Tap Edit in the top corner, then tap Add Widget.")
                step(3, "Search for Hasta, pick a size, and tap Add Widget.")
                step(4, "Touch and hold the widget, then tap Edit Widget to choose a countdown.")
            } header: {
                Label("Home Screen", systemImage: "apps.iphone")
            }

            Section {
                step(1, "Touch and hold your Lock Screen, then tap Customize.")
                step(2, "Choose Lock Screen, then tap the area below the clock.")
                step(3, "Tap Hasta and choose a circular or rectangular widget.")
                step(4, "Tap the widget again to choose which countdown it shows.")
            } header: {
                Label("Lock Screen", systemImage: "lock.iphone")
            } footer: {
                Text("You can also add an inline countdown above the clock.")
            }
        }
    }

    private func step(_ number: Int, _ text: LocalizedStringKey) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text("\(number)")
                .font(.subheadline.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 24, height: 24)
                .background(Color.accentColor, in: .circle)
            Text(text)
        }
        .padding(.vertical, 2)
    }
}
