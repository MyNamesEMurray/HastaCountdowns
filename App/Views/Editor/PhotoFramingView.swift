import SwiftUI

struct PhotoFramingView: View {
    @Environment(\.dismiss) private var dismiss
    let countdown: Countdown
    let image: UIImage
    let onSave: (BackgroundFraming) -> Void

    @State private var framing: BackgroundFraming
    @State private var family: PreviewFamily = .small
    @GestureState private var dragTranslation: CGSize = .zero
    @GestureState private var pinchScale: CGFloat = 1

    init(countdown: Countdown, image: UIImage, onSave: @escaping (BackgroundFraming) -> Void) {
        self.countdown = countdown
        self.image = image
        self.onSave = onSave
        _framing = State(initialValue: countdown.backgroundFraming ?? .centered)
    }

    private let families: [PreviewFamily] = [.small, .medium, .large]

    var body: some View {
        let metrics = WidgetMetrics.current
        let size = containerSize(for: family, metrics: metrics)
        let live = liveFraming(containerSize: size)
        var preview = countdown
        preview.backgroundFraming = live

        return NavigationStack {
            VStack(spacing: 20) {
                Spacer(minLength: 0)
                HomeWidgetPreview(countdown: preview, image: image, size: size, metrics: metrics) {
                    content(for: preview)
                }
                .contentShape(.rect(cornerRadius: metrics.cornerRadius, style: .continuous))
                .gesture(
                    SimultaneousGesture(
                        DragGesture()
                            .updating($dragTranslation) { value, state, _ in state = value.translation }
                            .onEnded { value in
                                framing = framing.panned(by: value.translation, imageSize: image.size, containerSize: size)
                            },
                        MagnifyGesture()
                            .updating($pinchScale) { value, state, _ in state = value.magnification }
                            .onEnded { value in
                                framing = framing.zoomed(to: framing.zoom * value.magnification, imageSize: image.size, containerSize: size)
                            }
                    )
                )
                .animation(.snappy, value: family)

                Text("Drag to move the photo. Pinch to zoom.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Picker("Widget Size", selection: $family.animation(.snappy)) {
                    ForEach(families) { family in
                        Text(family.title).tag(family)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 320)

                Button("Reset", systemImage: "arrow.counterclockwise") {
                    withAnimation(.snappy) { framing = .centered }
                }
                .disabled(framing == .centered)

                Spacer(minLength: 0)
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Adjust Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        onSave(framing)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func liveFraming(containerSize: CGSize) -> BackgroundFraming {
        framing
            .zoomed(to: framing.zoom * pinchScale, imageSize: image.size, containerSize: containerSize)
            .panned(by: dragTranslation, imageSize: image.size, containerSize: containerSize)
    }

    private func containerSize(for family: PreviewFamily, metrics: WidgetMetrics) -> CGSize {
        switch family {
        case .small, .lockScreen: metrics.small
        case .medium: metrics.medium
        case .large: metrics.large
        }
    }

    @ViewBuilder
    private func content(for countdown: Countdown) -> some View {
        switch family {
        case .small, .lockScreen:
            SmallCountdownView(countdown: countdown, now: .now, hasImage: true)
        case .medium:
            MediumCountdownView(countdown: countdown, now: .now, hasImage: true)
        case .large:
            LargeCountdownView(countdown: countdown, now: .now, hasImage: true)
        }
    }
}
