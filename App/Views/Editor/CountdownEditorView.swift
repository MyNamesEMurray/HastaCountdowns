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
    @FocusState private var isTitleFocused: Bool

    private let original: Countdown
    private let isNew: Bool

    init(countdown: Countdown, isNew: Bool) {
        _draft = State(initialValue: countdown)
        original = countdown
        self.isNew = isNew
    }

    private var canSave: Bool {
        !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var hasChanges: Bool {
        draft != original
    }

    private var previewImage: UIImage? {
        guard purchases.isPremium, let id = draft.backgroundImageID else { return nil }
        return ImageCache.shared.image(for: id)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    EditorPreview(countdown: draft.resolved(isPremium: purchases.isPremium), image: previewImage)
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
                if isNew { isTitleFocused = true }
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
                    Button("Remove Photo", systemImage: "xmark.circle", role: .destructive) {
                        withAnimation { draft.backgroundImageID = nil }
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
            Text("Photos stay on your device and are only used for your widgets.")
        }
    }

    private var unitSection: some View {
        Section("Show Time In") {
            Picker("Units", selection: $draft.unit) {
                ForEach(DisplayUnit.allCases) { unit in
                    Text(unit.title).tag(unit)
                }
            }
            .pickerStyle(.segmented)
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets())
        }
    }

    private var remindersSection: some View {
        Section {
            ForEach(Reminder.allCases) { reminder in
                Toggle(reminder.title(isAllDay: draft.isAllDay), isOn: Binding(
                    get: { draft.reminders.contains(reminder) },
                    set: { isOn in
                        if isOn {
                            draft.reminders.insert(reminder)
                        } else {
                            draft.reminders.remove(reminder)
                        }
                    }
                ))
            }
        } header: {
            Text("Reminders")
        } footer: {
            if draft.isAllDay {
                Text("All-day reminders arrive at \(ReminderPreferences.formattedTime). You can change this in Settings.")
            }
        }
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
            withAnimation { draft.backgroundImageID = id }
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

private struct EditorPreview: View {
    let countdown: Countdown
    let image: UIImage?

    var body: some View {
        HStack(spacing: 12) {
            WidgetPreviewFrame(countdown: countdown, image: image, cornerRadius: 22, padding: 14) {
                SmallCountdownView(countdown: countdown, now: .now, hasImage: image != nil)
            }
            .frame(width: 150, height: 150)
            .shadow(color: .black.opacity(0.1), radius: 10, y: 4)

            LockScreenPreview(countdown: countdown, now: .now, height: 150)
                .frame(maxWidth: 220)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .animation(.snappy, value: countdown)
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
