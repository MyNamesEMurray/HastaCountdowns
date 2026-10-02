import Photos
import PhotosUI
import SwiftUI

struct CountdownEditorView: View {
    @Environment(CountdownStore.self) private var store
    @Environment(PurchaseManager.self) private var purchases
    @Environment(\.dismiss) private var dismiss

    @State private var draft: Countdown
    @State private var createdImageIDs: [String] = []
    @State private var photoItem: PhotosPickerItem?
    @State private var isLoadingPhoto = false
    @State private var isShowingPaywall = false
    @State private var isConfirmingDelete = false
    @State private var editingReminder: ReminderDraft?
    @State private var previewFamily: PreviewFamily = .small
    @State private var liveSession: LivePhotoSession?
    @State private var lastLiveSession: LivePhotoSession?
    @State private var isFramingPhoto = false
    @FocusState private var isTitleFocused: Bool

    private let original: Countdown
    private let isNew: Bool

    init(countdown: Countdown, isNew: Bool) {
        var normalized = countdown
        normalized.adoptCurrentTimeZone()
        _draft = State(initialValue: normalized)
        original = normalized
        self.isNew = isNew
    }

    private var canSave: Bool {
        !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hasChanges: Bool {
        draft != original
    }

    private var previewUpNext: [Countdown] {
        store.upcoming()
            .filter { $0.id != draft.id }
            .map { $0.resolved(isPremium: purchases.isPremium) }
    }

    private var previewImage: UIImage? {
        guard purchases.isPremium, let id = draft.backgroundImageID else { return nil }
        return ImageCache.shared.image(for: id)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    WidgetFamilyPreview(
                        countdown: draft.resolved(isPremium: purchases.isPremium),
                        image: previewImage,
                        upNext: previewUpNext,
                        family: $previewFamily
                    )
                    .padding(.vertical, 8)
                    .animation(.snappy, value: draft)
                }
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets())

                detailsSection
                appearanceSection
                styleSection
                typefaceSection
                photoSection
                unitSection
                remindersSection

                if !isNew {
                    Section {
                        Button("Delete Countdown", role: .destructive) {
                            isConfirmingDelete = true
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }
            .navigationTitle(isNew ? "New Countdown" : "Edit Countdown")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel", action: cancel)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(isNew ? "Add" : "Done", action: save)
                        .fontWeight(.semibold)
                        .disabled(!canSave)
                }
            }
            .sheet(isPresented: $isShowingPaywall) {
                PremiumView()
            }
            .sheet(item: $liveSession) { session in
                LivePhotoStudioView(session: session) { image in
                    useProcessedPhoto(image)
                }
            }
            .sheet(isPresented: $isFramingPhoto) {
                if let image = previewImage {
                    PhotoFramingView(
                        countdown: draft.resolved(isPremium: purchases.isPremium),
                        image: image,
                        upNext: previewUpNext
                    ) { framing in
                        withAnimation { draft.backgroundFraming = framing == .centered ? nil : framing }
                    }
                }
            }
            .sheet(item: $editingReminder) { request in
                ReminderEditorView(
                    rule: request.rule,
                    isAllDay: draft.isAllDay,
                    isNew: request.isNew,
                    onSave: saveReminder,
                    onDelete: { deleteReminder(request.rule) }
                )
            }
            .confirmationDialog("Delete \(draft.displayTitle)?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
                Button("Delete Countdown", role: .destructive) {
                    discardCreatedImages()
                    store.delete(original)
                    dismiss()
                }
            }
            .onChange(of: photoItem) { _, item in
                guard let item else { return }
                loadPhoto(item)
            }
            .onAppear {
                if isNew && ScreenshotMode.current == nil { isTitleFocused = true }
            }
        }
        .interactiveDismissDisabled(hasChanges)
    }

    private var detailsSection: some View {
        Section {
            TextField("Title", text: $draft.title)
                .font(.body.weight(.medium))
                .focused($isTitleFocused)
                .submitLabel(.done)
            Toggle("All-Day", isOn: $draft.isAllDay.animation())
            DatePicker(
                "Date",
                selection: $draft.date,
                displayedComponents: draft.isAllDay ? [.date] : [.date, .hourAndMinute]
            )
            Picker("Repeat", selection: $draft.repeatRule) {
                ForEach(RepeatRule.allCases) { rule in
                    Text(rule.title).tag(rule)
                }
            }
        }
    }

    private var appearanceSection: some View {
        Section("Symbol & Color") {
            NavigationLink {
                SymbolPickerView(selection: $draft.symbol, tint: draft.tint)
            } label: {
                LabeledContent("Symbol") {
                    Image(systemName: draft.symbol)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(draft.tint)
                }
            }
            ColorPaletteView(
                selection: $draft.color,
                customHex: $draft.customColorHex,
                isPremium: purchases.isPremium,
                onLocked: { isShowingPaywall = true }
            )
        }
    }

    private var styleSection: some View {
        Section {
            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    ForEach(WidgetStyle.allCases) { style in
                        let isLocked = style.isPremium && !purchases.isPremium
                        Button {
                            if isLocked {
                                isShowingPaywall = true
                            } else {
                                withAnimation(.snappy) { draft.style = style }
                            }
                        } label: {
                            StyleSwatch(countdown: draft, style: style, isSelected: draft.style == style, isLocked: isLocked)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 2)
            }
            .scrollIndicators(.hidden)
        } header: {
            Text("Widget Style")
        }
    }

    private var typefaceSection: some View {
        Section {
            ScrollView(.horizontal) {
                HStack(spacing: 10) {
                    ForEach(Typeface.allCases) { typeface in
                        let isLocked = typeface.isPremium && !purchases.isPremium
                        Button {
                            if isLocked {
                                isShowingPaywall = true
                            } else {
                                withAnimation(.snappy) { draft.typeface = typeface }
                            }
                        } label: {
                            TypefaceChip(typeface: typeface, tint: draft.tint, isSelected: draft.typeface == typeface, isLocked: isLocked)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 2)
            }
            .scrollIndicators(.hidden)
        } header: {
            Text("Typeface")
        }
    }

    private var photoSection: some View {
        Section {
            if purchases.isPremium {
                PhotosPicker(selection: $photoItem, matching: .images, photoLibrary: .shared()) {
                    HStack {
                        Label(draft.backgroundImageID == nil ? "Choose Photo" : "Change Photo", systemImage: "photo.on.rectangle")
                        Spacer()
                        if isLoadingPhoto { ProgressView() }
                    }
                }
                if draft.backgroundImageID != nil {
                    Button {
                        isFramingPhoto = true
                    } label: {
                        Label("Adjust Position & Zoom", systemImage: "crop")
                    }
                    if let lastLiveSession {
                        Button {
                            liveSession = lastLiveSession
                        } label: {
                            Label("Live Photo Effects", systemImage: "livephoto")
                        }
                    }
                    Button("Remove Photo", systemImage: "xmark.circle", role: .destructive) {
                        withAnimation {
                            draft.backgroundImageID = nil
                            draft.backgroundFraming = nil
                            lastLiveSession = nil
                        }
                    }
                }
            } else {
                Button {
                    isShowingPaywall = true
                } label: {
                    HStack {
                        Label("Choose Photo", systemImage: "photo.on.rectangle")
                        Spacer()
                        PremiumBadge()
                    }
                }
            }
        } header: {
            Text("Background Photo")
        } footer: {
            Text("Photos stay private on your devices and iCloud, and are only used for your widgets. Choose a Live Photo to pick a different frame or make a long exposure.")
        }
    }

    private var unitSection: some View {
        Section {
            Picker("Show Time In", selection: $draft.unit) {
                ForEach(DisplayUnit.allCases) { unit in
                    Text(unit.title).tag(unit)
                }
            }
        } footer: {
            Text(draft.unit.detail)
        }
    }

    private var remindersSection: some View {
        let defaultTime = ReminderPreferences.time
        let rules = draft.reminders.sortedByLeadTime
        let presets = ReminderRule.presets(isAllDay: draft.isAllDay)
            .filter { preset in !draft.reminders.contains { $0.matches(preset) } }
        return Section {
            ForEach(rules) { rule in
                Button {
                    editingReminder = ReminderDraft(rule: rule, isNew: false)
                } label: {
                    HStack {
                        Label {
                            Text(rule.title(isAllDay: draft.isAllDay, defaultTime: defaultTime))
                        } icon: {
                            Image(systemName: "bell.fill")
                                .foregroundStyle(draft.tint)
                        }
                        Spacer(minLength: 8)
                        Image(systemName: "chevron.right")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .tint(.primary)
            }
            .onDelete { offsets in
                let ids = Set(offsets.map { rules[$0].id })
                withAnimation { draft.reminders.removeAll { ids.contains($0.id) } }
            }

            Menu {
                ForEach(Array(presets.enumerated()), id: \.offset) { _, preset in
                    Button(preset.title(isAllDay: draft.isAllDay, defaultTime: defaultTime)) {
                        withAnimation { draft.reminders.append(ReminderRule(amount: preset.amount, unit: preset.unit)) }
                    }
                }
                Divider()
                Button("Custom…", systemImage: "slider.horizontal.3") {
                    editingReminder = ReminderDraft(rule: ReminderRule(amount: 1, unit: .days), isNew: true)
                }
            } label: {
                Label("Add Reminder", systemImage: "plus")
            }
        } header: {
            Text("Reminders")
        } footer: {
            if draft.reminders.isEmpty {
                Text("No reminders for this countdown.")
            } else if draft.isAllDay {
                Text("Reminders without a custom time arrive at \(ReminderPreferences.formattedTime), which you can change in Settings.")
            }
        }
    }

    private func saveReminder(_ rule: ReminderRule) {
        withAnimation {
            if let index = draft.reminders.firstIndex(where: { $0.id == rule.id }) {
                draft.reminders[index] = rule
            } else {
                draft.reminders.append(rule)
            }
        }
    }

    private func deleteReminder(_ rule: ReminderRule) {
        withAnimation { draft.reminders.removeAll { $0.id == rule.id } }
    }

    private func loadPhoto(_ item: PhotosPickerItem) {
        isLoadingPhoto = true
        Task {
            defer {
                isLoadingPhoto = false
                photoItem = nil
            }
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let id = try? BackgroundImageStore.save(data) else { return }
            createdImageIDs.append(id)
            withAnimation {
                draft.backgroundImageID = id
                draft.backgroundFraming = nil
            }
            lastLiveSession = nil

            if let livePhoto = try? await item.loadTransferable(type: PHLivePhoto.self),
               let videoURL = try? await LivePhotoProcessor.pairedVideoURL(for: livePhoto),
               let keyPhoto = ImageCache.shared.image(for: id) {
                let session = LivePhotoSession(videoURL: videoURL, keyPhoto: keyPhoto)
                lastLiveSession = session
                liveSession = session
            }
        }
    }

    private func useProcessedPhoto(_ image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.92),
              let id = try? BackgroundImageStore.save(data) else { return }
        createdImageIDs.append(id)
        withAnimation {
            draft.backgroundImageID = id
            draft.backgroundFraming = nil
        }
    }

    private func save() {
        draft.title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        for id in createdImageIDs where id != draft.backgroundImageID {
            BackgroundImageStore.delete(id)
        }
        store.save(draft)
        if !draft.reminders.isEmpty {
            Task {
                if await ReminderScheduler.requestAuthorizationIfNeeded() {
                    store.refreshSideEffects()
                }
            }
        }
        dismiss()
    }

    private func cancel() {
        discardCreatedImages()
        dismiss()
    }

    private func discardCreatedImages() {
        for id in createdImageIDs {
            BackgroundImageStore.delete(id)
        }
    }
}

extension ReminderPreferences {
    static var formattedTime: String {
        let date = Calendar.current.date(from: time) ?? .now
        return date.formatted(date: .omitted, time: .shortened)
    }
}

private struct StyleSwatch: View {
    let countdown: Countdown
    let style: WidgetStyle
    let isSelected: Bool
    let isLocked: Bool

    var body: some View {
        var variant = countdown
        variant.style = style
        variant.backgroundImageID = nil
        let palette = CountdownPalette(countdown: variant, hasImage: false)
        return VStack(spacing: 6) {
            WidgetPreviewFrame(countdown: variant, image: nil, cornerRadius: 16, padding: 10) {
                VStack(alignment: .leading, spacing: 0) {
                    Image(systemName: variant.symbol)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(palette.accent)
                    Spacer(minLength: 0)
                    Text(variant.status().number)
                        .font(variant.typeface.font(size: 24))
                        .foregroundStyle(palette.number)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
            .frame(width: 72, height: 72)
            .overlay {
                RoundedRectangle(cornerRadius: 19, style: .continuous)
                    .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 3)
                    .padding(-4)
            }
            .overlay(alignment: .topTrailing) {
                if isLocked {
                    LockBadge().offset(x: 6, y: -6)
                }
            }
            Text(style.title)
                .font(.caption.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .primary : .secondary)
        }
        .padding(.top, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(style.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

private struct TypefaceChip: View {
    let typeface: Typeface
    let tint: Color
    let isSelected: Bool
    let isLocked: Bool

    var body: some View {
        VStack(spacing: 4) {
            Text("42")
                .font(typeface.font(size: 26))
                .foregroundStyle(isSelected ? tint : .primary)
            Text(typeface.title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(width: 76, height: 64)
        .background(Color(uiColor: .tertiarySystemFill), in: .rect(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(isSelected ? tint : .clear, lineWidth: 2)
        }
        .overlay(alignment: .topTrailing) {
            if isLocked {
                LockBadge().offset(x: 5, y: -5)
            }
        }
        .padding(.top, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(typeface.title)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

struct LockBadge: View {
    var body: some View {
        Image(systemName: "lock.fill")
            .font(.system(size: 9, weight: .bold))
            .foregroundStyle(.white)
            .frame(width: 20, height: 20)
            .background(Color.secondary, in: .circle)
            .overlay(Circle().strokeBorder(Color(uiColor: .systemBackground), lineWidth: 1.5))
    }
}

struct PremiumBadge: View {
    var body: some View {
        Text("PREMIUM")
            .font(.caption2.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 7)
            .padding(.vertical, 3)
            .background(
                LinearGradient(colors: [.orange, .pink], startPoint: .leading, endPoint: .trailing),
                in: .capsule
            )
    }
}

struct ReminderDraft: Identifiable {
    let rule: ReminderRule
    let isNew: Bool

    var id: UUID { rule.id }
}
