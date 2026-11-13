import Photos
import PhotosUI
import SwiftUI

struct CountdownEditorView: View {
    @Environment(CountdownStore.self) private var store
    @Environment(PurchaseManager.self) private var purchases
    @Environment(\.dismiss) private var dismiss

    @State private var draft: Countdown
    @State private var createdImageIDs: [String] = []
    @State private var photoItems: [PhotosPickerItem] = []
    @State private var isPhotoBackground: Bool
    @State private var stashedPhotos: PhotoSet?
    @State private var isShowingRotateError = false
    @State private var framingTarget: FramingTarget?
    @State private var isLoadingPhoto = false
    @State private var isShowingPaywall = false
    @State private var isConfirmingDelete = false
    @State private var editingReminder: ReminderDraft?
    @State private var previewFamily: PreviewFamily = .small
    @State private var liveSession: LivePhotoSession?
    @State private var lastLiveSession: LivePhotoSession?
    @State private var isEditingRepeat = false
    @State private var isImportingEvent = false
    @FocusState private var isTitleFocused: Bool

    private let original: Countdown
    private let isNew: Bool

    init(countdown: Countdown, isNew: Bool) {
        var normalized = countdown
        normalized.adoptCurrentTimeZone()
        _draft = State(initialValue: normalized)
        _isPhotoBackground = State(initialValue: normalized.backgroundImageID != nil)
        original = normalized
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

    private var screenHeight: CGFloat {
        (UIApplication.shared.connectedScenes.first as? UIWindowScene)?.screen.bounds.height ?? 852
    }

    var body: some View {
        NavigationStack {
            Form {
                if isNew {
                    Section {
                        Button("Import from Calendar", systemImage: "calendar") {
                            isImportingEvent = true
                        }
                    }
                }

                detailsSection
                appearanceSection
                backgroundSection
                if isPhotoBackground {
                    photoSection
                } else if draft.style == .gradient {
                    gradientSection
                }
                fontColorSection
                typefaceSection
                progressSection
                sinceSection
                liveActivitySection
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
            .safeAreaInset(edge: .top, spacing: 0) {
                VStack(spacing: 0) {
                    WidgetFamilyPreview(
                        countdown: draft.resolved(isPremium: purchases.isPremium),
                        image: previewImage,
                        family: $previewFamily,
                        maxPreviewHeight: screenHeight * (isTitleFocused ? 0.18 : 0.3)
                    )
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    .animation(.snappy, value: draft)
                    Divider()
                }
                .background(.bar)
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
            .navigationDestination(isPresented: $isEditingRepeat) {
                RepeatRuleEditorView(rule: $draft.repeatRule, date: draft.date)
            }
            .sheet(isPresented: $isImportingEvent) {
                CalendarEventPickerView { event in
                    var imported = event
                    imported.adoptCurrentTimeZone()
                    withAnimation {
                        draft.title = imported.title
                        draft.date = imported.date
                        draft.isAllDay = imported.isAllDay
                        draft.timeZoneIdentifier = imported.timeZoneIdentifier
                        draft.repeatRule = imported.repeatRule
                    }
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
            .sheet(item: $framingTarget) { target in
                if let image = ImageCache.shared.image(for: target.id) {
                    PhotoFramingView(
                        countdown: draft.resolved(isPremium: purchases.isPremium),
                        image: image,
                        initialFraming: draft.framing(for: target.id)
                    ) { framing, turns in
                        var id = target.id
                        if turns != 0 {
                            guard let rotated = BackgroundImageStore.saveRotated(id, quarterTurns: turns) else {
                                isShowingRotateError = true
                                return
                            }
                            createdImageIDs.append(rotated)
                            draft.replaceBackground(id, with: rotated)
                            id = rotated
                        }
                        withAnimation { draft.setFraming(framing, for: id) }
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
            .alert("Couldn't Rotate Photo", isPresented: $isShowingRotateError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text("The photo was left as it was. Check that your iPhone has free storage and try again.")
            }
            .confirmationDialog("Delete \(draft.displayTitle)?", isPresented: $isConfirmingDelete, titleVisibility: .visible) {
                Button("Delete Countdown", role: .destructive) {
                    discardCreatedImages()
                    store.delete(original)
                    dismiss()
                }
            }
            .onChange(of: photoItems) { _, items in
                guard !items.isEmpty else { return }
                if items.count == 1 {
                    loadPhoto(items[0])
                } else {
                    loadPhotos(items)
                }
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
            LabeledContent("Repeat") {
                Menu {
                    Picker("Repeat", selection: $draft.repeatRule) {
                        ForEach(RepeatRule.presets, id: \.self) { rule in
                            Text(rule.title).tag(rule)
                        }
                        if draft.repeatRule.isCustom {
                            Text(draft.repeatRule.title).tag(draft.repeatRule)
                        }
                    }
                    Divider()
                    Button("Custom…") { isEditingRepeat = true }
                } label: {
                    HStack(spacing: 4) {
                        Text(draft.repeatRule.title)
                            .multilineTextAlignment(.trailing)
                        Image(systemName: "chevron.up.chevron.down")
                            .imageScale(.small)
                    }
                    .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var appearanceSection: some View {
        Section("Symbol") {
            NavigationLink {
                SymbolPickerView(selection: $draft.symbol, tint: draft.tint)
            } label: {
                LabeledContent("Symbol") {
                    SymbolSwatch(
                        countdown: draft.resolved(isPremium: purchases.isPremium),
                        image: isPhotoBackground ? previewImage : nil
                    )
                }
            }
        }
    }

    private var backgroundSection: some View {
        Section {
            ScrollView(.horizontal) {
                HStack(spacing: 12) {
                    Button {
                        if purchases.isPremium {
                            withAnimation(.snappy) {
                                isPhotoBackground = true
                                if draft.backgroundImageID == nil, let stashedPhotos {
                                    draft.apply(stashedPhotos)
                                }
                            }
                        } else {
                            isShowingPaywall = true
                        }
                    } label: {
                        PhotoSwatch(
                            countdown: draft,
                            imageID: draft.backgroundImageID,
                            isSelected: isPhotoBackground,
                            isLocked: !purchases.isPremium
                        )
                    }
                    .buttonStyle(.plain)
                    ForEach(WidgetStyle.allCases) { style in
                        let isLocked = style.isPremium && !purchases.isPremium
                        Button {
                            if isLocked {
                                isShowingPaywall = true
                            } else {
                                withAnimation(.snappy) {
                                    isPhotoBackground = false
                                    if draft.backgroundImageID != nil { stashedPhotos = draft.photoSet }
                                    draft.setBackgrounds([])
                                    lastLiveSession = nil
                                    draft.style = style
                                }
                            }
                        } label: {
                            StyleSwatch(countdown: draft, style: style, isSelected: !isPhotoBackground && draft.style == style, isLocked: isLocked)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
            }
            .scrollIndicators(.hidden)
            ColorPaletteView(
                selection: $draft.color,
                customHex: $draft.customColorHex,
                isPremium: purchases.isPremium,
                onLocked: { isShowingPaywall = true }
            )
        } header: {
            Text("Widget Background")
        } footer: {
            Text("The color tints the background styles. It also colors this countdown's Live Activity.")
        }
    }

    private var fontColorSection: some View {
        Section {
            Toggle("Auto Font Color", isOn: $draft.autoFontColor.animation())
            if draft.autoFontColor && isPhotoBackground {
                Toggle("Adapt to Each Area", isOn: $draft.zoneFontColor)
            }
            if !draft.autoFontColor {
                ColorPicker(
                    "Font Color",
                    selection: Binding(
                        get: { draft.fontColor },
                        set: { draft.fontColorHex = $0.hexString }
                    ),
                    supportsOpacity: false
                )
            }
        } header: {
            Text("Font Color")
        } footer: {
            Text(fontColorFooter)
        }
    }

    private var fontColorFooter: String {
        if !draft.autoFontColor {
            return String(localized: "This color is used on every background.")
        }
        if isPhotoBackground && draft.zoneFontColor {
            return String(localized: "The icon and the text each pick light or dark to match the part of the photo behind them. With a slideshow, each photo gets its own colors.")
        }
        return String(localized: "Picks light or dark text to match the background. With a slideshow, each photo gets its own.")
    }

    private var gradientSection: some View {
        let gradient = draft.customGradient ?? .starting(from: draft.tint)
        return Section {
            ColorPicker("Start Color", selection: gradientColor(\.startHex, fallback: gradient.startHex), supportsOpacity: false)
            ColorPicker("End Color", selection: gradientColor(\.endHex, fallback: gradient.endHex), supportsOpacity: false)
            Picker("Direction", selection: Binding(
                get: { gradient.direction },
                set: { direction in
                    var updated = draft.customGradient ?? gradient
                    updated.direction = direction
                    draft.customGradient = updated
                }
            )) {
                ForEach(GradientDirection.allCases) { Text($0.title).tag($0) }
            }
            .pickerStyle(.segmented)
            Button("Swap Colors", systemImage: "arrow.left.arrow.right") {
                var updated = draft.customGradient ?? gradient
                swap(&updated.startHex, &updated.endHex)
                withAnimation { draft.customGradient = updated }
            }
            if draft.customGradient != nil {
                Button("Reset to Match Color", systemImage: "arrow.counterclockwise") {
                    withAnimation { draft.customGradient = nil }
                }
            }
        } header: {
            Text("Gradient Colors")
        }
    }

    private func gradientColor(_ keyPath: WritableKeyPath<CustomGradient, String>, fallback: String) -> Binding<Color> {
        Binding(
            get: { Color(hex: draft.customGradient?[keyPath: keyPath] ?? fallback) ?? .blue },
            set: { color in
                var updated = draft.customGradient ?? .starting(from: draft.tint)
                updated[keyPath: keyPath] = color.hexString ?? fallback
                draft.customGradient = updated
            }
        )
    }

    private var liveActivitySection: some View {
        let global = LiveActivityPreferences.pushEnabled
        let isOn = draft.startsLiveActivity(globalEnabled: global)
        return Section {
            if purchases.isPremium {
                Toggle(isOn: Binding(
                    get: { isOn },
                    set: { draft.setLiveActivity($0, globalEnabled: global) }
                )) {
                    Label("Live Activity", systemImage: "platter.filled.bottom.iphone")
                }
            } else {
                Button {
                    isShowingPaywall = true
                } label: {
                    HStack {
                        Label("Live Activity", systemImage: "platter.filled.bottom.iphone")
                        Spacer()
                        PremiumBadge()
                    }
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text("Lock Screen")
        } footer: {
            Text(isOn && purchases.isPremium
                ? String(localized: "Shows this countdown on your Lock Screen and Dynamic Island \(LiveActivityPreferences.leadHours) hours before it happens.")
                : String(localized: "Turn on to follow this countdown on your Lock Screen and Dynamic Island as it gets close."))
        }
    }

    private var sinceSection: some View {
        Section {
            if purchases.isPremium {
                TextField("Label after the date, like Together", text: $draft.sinceLabel)
            } else {
                Button {
                    isShowingPaywall = true
                } label: {
                    HStack {
                        Text("Since Label")
                        Spacer()
                        PremiumBadge()
                    }
                }
                .buttonStyle(.plain)
            }
        } header: {
            Text("After the Date")
        } footer: {
            Text("Once the date has passed, widgets count up with this label, such as Together or Sober.")
        }
    }

    private var progressSection: some View {
        Section {
            Toggle(isOn: Binding(
                get: { draft.showsProgress && purchases.isPremium },
                set: { isOn in
                    if purchases.isPremium {
                        draft.showsProgress = isOn
                    } else {
                        isShowingPaywall = true
                    }
                }
            )) {
                HStack {
                    Text("Show Progress")
                    if !purchases.isPremium { LockBadge() }
                }
            }
            if draft.showsProgress && purchases.isPremium {
                Picker("Style", selection: $draft.progressStyle) {
                    ForEach(ProgressDisplay.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
            }
        } header: {
            Text("Progress")
        } footer: {
            Text("Shows how close you are to the date. It starts empty on the day you create the countdown and fills up until the date arrives. Not shown for repeating countdowns.")
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
                            TypefaceChip(typeface: typeface, isSelected: draft.typeface == typeface, isLocked: isLocked)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
            }
            .scrollIndicators(.hidden)
        } header: {
            Text("Typeface")
        }
    }

    private var photoSection: some View {
        Section {
            if purchases.isPremium {
                PhotosPicker(
                    selection: $photoItems,
                    maxSelectionCount: 1 + Countdown.maxExtraBackgrounds,
                    matching: .images,
                    photoLibrary: .shared()
                ) {
                    HStack {
                        Label(draft.backgroundImageID == nil ? "Choose Photos" : "Change Photos", systemImage: "photo.on.rectangle")
                        Spacer()
                        if isLoadingPhoto { ProgressView() }
                    }
                }
                if draft.backgroundImageID != nil {
                    photoStrip
                    if let lastLiveSession, draft.allBackgroundImageIDs.count == 1 {
                        Button {
                            liveSession = lastLiveSession
                        } label: {
                            Label("Live Photo Effects", systemImage: "livephoto")
                        }
                    }
                    Button("Remove Photos", systemImage: "xmark.circle", role: .destructive) {
                        withAnimation {
                            draft.setBackgrounds([])
                            lastLiveSession = nil
                        }
                    }
                }
            } else {
                Button {
                    isShowingPaywall = true
                } label: {
                    HStack {
                        Label("Choose Photos", systemImage: "photo.on.rectangle")
                        Spacer()
                        PremiumBadge()
                    }
                }
            }
        } header: {
            Text("Photos")
        } footer: {
            Text(photoFooter)
        }
    }

    private var photoFooter: String {
        draft.allBackgroundImageIDs.count > 1
            ? String(localized: "The widget changes photo every hour. Tap a photo to adjust its position and zoom, or tap the x to remove it.")
            : String(localized: "Choose several photos to turn the widget into a slideshow. Photos stay private on your devices and iCloud, and are only used for your widgets. Choose a Live Photo to pick a different frame or make a long exposure.")
    }

    private var photoStrip: some View {
        ScrollView(.horizontal) {
            HStack(spacing: 12) {
                ForEach(Array(draft.allBackgroundImageIDs.enumerated()), id: \.element) { index, id in
                    ZStack(alignment: .topTrailing) {
                        Group {
                            if let image = ImageCache.shared.image(for: id, maxPixelSize: 300) {
                                Image(uiImage: image).resizable().scaledToFill()
                            } else {
                                Color.secondary.opacity(0.2)
                            }
                        }
                        .frame(width: 72, height: 72)
                        .clipShape(.rect(cornerRadius: 12, style: .continuous))
                        .overlay(alignment: .bottomTrailing) {
                            Image(systemName: "crop")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.white)
                                .padding(5)
                                .background(.black.opacity(0.5), in: .circle)
                                .padding(4)
                        }
                        .contentShape(.rect(cornerRadius: 12, style: .continuous))
                        .onTapGesture { framingTarget = FramingTarget(id: id) }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel(Text("Adjust photo \(index + 1)"))
                        .accessibilityAddTraits(.isButton)

                        Button {
                            withAnimation { draft.removeBackground(id) }
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .symbolRenderingMode(.palette)
                                .foregroundStyle(.white, .black.opacity(0.65))
                                .font(.title3)
                        }
                        .buttonStyle(.borderless)
                        .accessibilityLabel(Text("Remove photo \(index + 1)"))
                        .offset(x: 7, y: -7)
                    }
                }
            }
            .padding(.top, 10)
            .padding(.trailing, 8)
            .padding(.bottom, 4)
        }
        .scrollIndicators(.hidden)
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
                photoItems = []
            }
            guard let data = try? await item.loadTransferable(type: Data.self),
                  let id = await Self.saveOffMain(data) else { return }
            createdImageIDs.append(id)
            withAnimation { draft.setBackgrounds([id]) }
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

    private static func saveOffMain(_ data: Data) async -> String? {
        await Task.detached { try? BackgroundImageStore.save(data) }.value
    }

    private func loadPhotos(_ items: [PhotosPickerItem]) {
        isLoadingPhoto = true
        Task {
            defer {
                isLoadingPhoto = false
                photoItems = []
            }
            var ids: [String] = []
            for item in items {
                guard let data = try? await item.loadTransferable(type: Data.self),
                      let id = await Self.saveOffMain(data) else { continue }
                createdImageIDs.append(id)
                ids.append(id)
            }
            guard !ids.isEmpty else { return }
            lastLiveSession = nil
            withAnimation { draft.setBackgrounds(ids) }
        }
    }

    private func useProcessedPhoto(_ image: UIImage) {
        guard let data = image.jpegData(compressionQuality: 0.92),
              let id = try? BackgroundImageStore.save(data) else { return }
        createdImageIDs.append(id)
        withAnimation { draft.setBackgrounds([id]) }
    }

    private func save() {
        draft.title = draft.title.trimmingCharacters(in: .whitespacesAndNewlines)
        for id in createdImageIDs where !draft.allBackgroundImageIDs.contains(id) {
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

private struct PhotoSwatch: View {
    let countdown: Countdown
    let imageID: String?
    let isSelected: Bool
    let isLocked: Bool

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                if let imageID, let image = ImageCache.shared.image(for: imageID, maxPixelSize: 200) {
                    Image(uiImage: image).resizable().scaledToFill()
                } else {
                    Rectangle().fill(countdown.tint.gradient)
                    Image(systemName: "photo.on.rectangle")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.white)
                }
            }
            .frame(width: 72, height: 72)
            .clipShape(.rect(cornerRadius: 16, style: .continuous))
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
            Text("Photo")
                .font(.caption.weight(isSelected ? .semibold : .regular))
                .foregroundStyle(isSelected ? .primary : .secondary)
        }
        .padding(.top, 4)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Photo"))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// The symbol on the real widget background, in the ink the widget will use.
private struct SymbolSwatch: View {
    let countdown: Countdown
    let image: UIImage?

    var body: some View {
        let zones = image?.zones(framing: countdown.backgroundFraming, containerSize: CGSize(width: 1, height: 1))
        let palette = CountdownPalette(countdown: countdown, hasImage: image != nil, photoZones: zones)
        WidgetPreviewFrame(countdown: countdown, image: image, cornerRadius: 9, padding: 0) {
            Image(systemName: countdown.symbol)
                .font(.body.weight(.semibold))
                .foregroundStyle(palette.headerAccent)
        }
        .frame(width: 34, height: 34)
    }
}

private struct TypefaceChip: View {
    let typeface: Typeface
    let isSelected: Bool
    let isLocked: Bool

    var body: some View {
        VStack(spacing: 4) {
            Text("42")
                .font(typeface.font(size: 26))
                .foregroundStyle(.primary)
            Text(typeface.title)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
        .frame(width: 76, height: 64)
        .background(Color(uiColor: .tertiarySystemFill), in: .rect(cornerRadius: 14, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: 17, style: .continuous)
                .strokeBorder(isSelected ? Color.accentColor : .clear, lineWidth: 3)
                .padding(-4)
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

private struct FramingTarget: Identifiable {
    let id: String
}
