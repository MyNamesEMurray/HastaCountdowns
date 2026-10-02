import SwiftUI

struct LivePhotoSession: Identifiable {
    let id = UUID()
    let videoURL: URL
    let keyPhoto: UIImage
}

struct LivePhotoStudioView: View {
    enum Mode: String, CaseIterable, Identifiable {
        case keyPhoto = "Key Photo"
        case frame = "Choose Frame"
        case longExposure = "Long Exposure"

        var id: String { rawValue }

        var title: String {
            switch self {
            case .keyPhoto: String(localized: "Key Photo")
            case .frame: String(localized: "Choose Frame")
            case .longExposure: String(localized: "Long Exposure")
            }
        }
    }

    @Environment(\.dismiss) private var dismiss
    let session: LivePhotoSession
    let onUse: (UIImage) -> Void

    @State private var mode: Mode = .keyPhoto
    @State private var duration: Double = 0
    @State private var position: Double = 0.5
    @State private var thumbnails: [UIImage] = []
    @State private var frameImage: UIImage?
    @State private var exposureImage: UIImage?
    @State private var isWorking = false
    @State private var failed = false

    private var currentImage: UIImage? {
        switch mode {
        case .keyPhoto: session.keyPhoto
        case .frame: frameImage
        case .longExposure: exposureImage
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                ZStack {
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .fill(Color(uiColor: .secondarySystemGroupedBackground))
                    if let currentImage {
                        Image(uiImage: currentImage)
                            .resizable()
                            .scaledToFit()
                            .clipShape(.rect(cornerRadius: 24, style: .continuous))
                    }
                    if isWorking {
                        ProgressView()
                            .controlSize(.large)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Picker("Effect", selection: $mode) {
                    ForEach(Mode.allCases) { mode in
                        Text(mode.title).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                Group {
                    switch mode {
                    case .keyPhoto:
                        Text("The photo the camera picked when you took this Live Photo.")
                    case .frame:
                        VStack(spacing: 10) {
                            ZStack {
                                HStack(spacing: 0) {
                                    ForEach(Array(thumbnails.enumerated()), id: \.offset) { _, thumbnail in
                                        Image(uiImage: thumbnail)
                                            .resizable()
                                            .scaledToFill()
                                            .frame(maxWidth: .infinity, maxHeight: 44)
                                            .clipped()
                                    }
                                }
                                .frame(height: 44)
                                .clipShape(.rect(cornerRadius: 8, style: .continuous))
                                Slider(value: $position, in: 0...1)
                                    .tint(.clear)
                            }
                            Text("Drag to choose the frame to use.")
                        }
                    case .longExposure:
                        Text("Blends every frame together, so moving things like water and lights turn smooth. Works best when the phone was held still.")
                    }
                }
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(minHeight: 70, alignment: .top)

                if failed {
                    Text("This effect isn't available for this Live Photo.")
                        .font(.footnote)
                        .foregroundStyle(.red)
                }
            }
            .padding()
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("Live Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Use Photo") {
                        if let currentImage {
                            onUse(currentImage)
                        }
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(currentImage == nil || isWorking)
                }
            }
            .task {
                duration = (try? await LivePhotoProcessor.duration(of: session.videoURL)) ?? 0
                thumbnails = await LivePhotoProcessor.thumbnails(from: session.videoURL, count: 10)
            }
            .task(id: TaskKey(mode: mode, position: mode == .frame ? position : 0)) {
                await update()
            }
        }
    }

    private struct TaskKey: Equatable {
        let mode: Mode
        let position: Double
    }

    private func update() async {
        failed = false
        switch mode {
        case .keyPhoto:
            isWorking = false
        case .frame:
            try? await Task.sleep(for: .milliseconds(120))
            guard !Task.isCancelled else { return }
            if duration == 0 {
                duration = (try? await LivePhotoProcessor.duration(of: session.videoURL)) ?? 0
            }
            isWorking = frameImage == nil
            do {
                let image = try await LivePhotoProcessor.frame(from: session.videoURL, at: duration * position)
                guard !Task.isCancelled else { return }
                frameImage = image
            } catch {
                failed = true
            }
            isWorking = false
        case .longExposure:
            guard exposureImage == nil else { return }
            isWorking = true
            do {
                exposureImage = try await LivePhotoProcessor.longExposure(from: session.videoURL)
            } catch {
                failed = true
            }
            isWorking = false
        }
    }
}
