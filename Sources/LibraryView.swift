import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @ObservedObject var mainModel: MainWindowModel
    @ObservedObject var model: LibraryViewModel
    @State private var showsMagnetSheet = false
    @FocusState private var magnetFieldIsFocused: Bool

    private var texts: LibraryTexts {
        LibraryTexts(language: mainModel.language)
    }

    var body: some View {
        libraryContent
        .alert(
            texts.removeMaterialQuestion(count: model.pendingDeletionTorrents.count),
            isPresented: deletionAlertIsPresented
        ) {
            Button(texts.cancel, role: .cancel) {
                model.cancelRemoval()
            }
            Button(texts.remove, role: .destructive) {
                model.confirmRemoval()
            }
        } message: {
            Text(deletionAlertMessage)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $showsMagnetSheet) {
            magnetSheet
        }
        .alert(item: $model.alert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK"))
            )
        }
        .onAppear {
            model.startPolling()
        }
        .onDisappear {
            model.stopPolling()
        }
        .onDrop(
            of: [UTType.fileURL.identifier],
            isTargeted: $model.isDropTargeted,
            perform: handleDrop
        )
        .background {
            LibraryKeyboardShortcutMonitor(
                onDelete: handleDeleteKey,
                onReturn: handleReturnKey
            )
            .frame(width: 0, height: 0)
        }
    }

    private var deletionAlertIsPresented: Binding<Bool> {
        Binding(
            get: { !model.pendingDeletionTorrents.isEmpty },
            set: { isPresented in
                if !isPresented {
                    model.cancelRemoval()
                }
            }
        )
    }

    private var deletionAlertMessage: String {
        let torrents = model.pendingDeletionTorrents
        let subject = torrents.count > 1
            ? texts.selectedMaterialCount(torrents.count)
            : (torrents.first?.displayTitle ?? "")
        return "\(subject)\n\n\(texts.removeMaterialHint(count: torrents.count))"
    }

    private var libraryContent: some View {
        Group {
            if model.displayMode == .compact {
                HStack(spacing: 12) {
                    torrentListPanel
                        .frame(width: 314)

                    torrentDetailPanel
                        .frame(maxWidth: .infinity)
                }
            } else {
                visualLibrary
            }
        }
        .frame(maxHeight: .infinity)
    }

    private var torrentListPanel: some View {
        VStack(spacing: 10) {
            HStack {
                Label(texts.library, systemImage: "film.stack")
                    .font(.headline)

                Spacer()

                LibraryModePicker(model: model, language: mainModel.language)

                Button {
                    model.refresh()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .disabled(model.isRefreshing || !mainModel.canStop)
                .help(texts.refresh)

                Menu {
                    Button {
                        showsMagnetSheet = true
                    } label: {
                        Label(texts.addMagnet, systemImage: "link")
                    }

                    Button {
                        model.chooseTorrentFiles(language: mainModel.language)
                    } label: {
                        Label(texts.addTorrentFile, systemImage: "doc.badge.plus")
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 17))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .disabled(model.isAdding || !mainModel.canStop)
            }

            TextField(texts.search, text: $model.searchText)
                .textFieldStyle(.roundedBorder)

            if !mainModel.canStop {
                serverUnavailable
            } else if model.filteredTorrents.isEmpty {
                emptyLibrary
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(model.filteredTorrents) { torrent in
                            TorrentLibraryRow(
                                torrent: torrent,
                                metadata: model.metadata(for: torrent),
                                language: mainModel.language,
                                isSelected: model.selectedTorrentIDs.contains(torrent.id)
                            ) {
                                select(torrent)
                            }
                            .contextMenu {
                                TorrentContextMenu(
                                    torrent: torrent,
                                    model: model,
                                    language: mainModel.language
                                )
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }

            HStack {
                if model.isAdding {
                    ProgressView()
                        .controlSize(.small)
                    Text(texts.adding)
                } else {
                    Text(texts.itemCount(model.torrents.count))
                }

                Spacer()

                Label(texts.dropHint, systemImage: "arrow.down.doc")
            }
            .font(.caption2)
            .foregroundStyle(model.isDropTargeted ? Color.accentColor : .secondary)
        }
        .padding(14)
        .libraryPanel()
        .overlay {
            if model.isDropTargeted {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.accentColor, style: StrokeStyle(
                        lineWidth: 2,
                        dash: [6, 4]
                    ))
            }
        }
    }

    private var visualLibrary: some View {
        VStack(spacing: 10) {
            HStack(spacing: 10) {
                Label(texts.library, systemImage: "film.stack")
                    .font(.headline)

                TextField(texts.search, text: $model.searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 260)

                Spacer()

                LibraryModePicker(model: model, language: mainModel.language)

                Button { model.refresh() } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.plain)
                .disabled(model.isRefreshing || !mainModel.canStop)

                Menu {
                    Button {
                        showsMagnetSheet = true
                    } label: {
                        Label(texts.addMagnet, systemImage: "link")
                    }
                    Button {
                        model.chooseTorrentFiles(language: mainModel.language)
                    } label: {
                        Label(texts.addTorrentFile, systemImage: "doc.badge.plus")
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 17))
                }
                .menuStyle(.borderlessButton)
                .fixedSize()
                .disabled(model.isAdding || !mainModel.canStop)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 11)
            .libraryPanel()

            if !mainModel.canStop {
                serverUnavailable
                    .libraryPanel()
            } else if model.filteredTorrents.isEmpty {
                emptyLibrary
                    .libraryPanel()
            } else {
                ScrollView {
                    if model.displayMode == .posters {
                        LazyVGrid(
                            columns: [GridItem(.adaptive(minimum: 150, maximum: 190), spacing: 14)],
                            spacing: 16
                        ) {
                            ForEach(model.filteredTorrents) { torrent in
                                TorrentPosterCard(
                                    torrent: torrent,
                                    metadata: model.metadata(for: torrent),
                                    language: mainModel.language,
                                    isSelected: model.selectedTorrentIDs.contains(torrent.id),
                                    select: { select(torrent) },
                                    play: {
                                        model.playFirstFile(
                                            in: torrent,
                                            language: mainModel.language
                                        )
                                    }
                                )
                                .contextMenu {
                                    TorrentContextMenu(
                                        torrent: torrent,
                                        model: model,
                                        language: mainModel.language
                                    )
                                }
                            }
                        }
                        .padding(14)
                    } else {
                        LazyVStack(spacing: 12) {
                            ForEach(model.filteredTorrents) { torrent in
                                TorrentLargeCard(
                                    torrent: torrent,
                                    metadata: model.metadata(for: torrent),
                                    language: mainModel.language,
                                    translationMode: mainModel.overviewTranslationMode,
                                    isSelected: model.selectedTorrentIDs.contains(torrent.id),
                                    select: { select(torrent) },
                                    play: {
                                        model.playFirstFile(
                                            in: torrent,
                                            language: mainModel.language
                                        )
                                    }
                                )
                                .contextMenu {
                                    TorrentContextMenu(
                                        torrent: torrent,
                                        model: model,
                                        language: mainModel.language
                                    )
                                }
                            }
                        }
                        .padding(14)
                    }
                }
                .libraryPanel()
            }
        }
    }

    @ViewBuilder
    private var torrentDetailPanel: some View {
        if let torrent = model.selectedTorrent {
            TorrentDetailView(
                torrent: torrent,
                model: model,
                metadata: model.metadata(for: torrent),
                language: mainModel.language,
                translationMode: mainModel.overviewTranslationMode
            )
            .padding(14)
            .libraryPanel()
        } else {
            VStack(spacing: 12) {
                Image(systemName: "film.stack")
                    .font(.system(size: 42, weight: .light))
                    .foregroundStyle(.secondary)
                Text(texts.selectMaterial)
                    .font(.headline)
                Text(texts.selectMaterialHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(14)
            .libraryPanel()
        }
    }

    private var magnetSheet: some View {
        VStack(alignment: .leading, spacing: 16) {
            Label(texts.addMagnet, systemImage: "link.badge.plus")
                .font(.title3.weight(.semibold))

            TextField("magnet:?xt=urn:btih:…", text: $model.magnetInput)
                .textFieldStyle(.roundedBorder)
                .focused($magnetFieldIsFocused)

            HStack {
                Text(texts.magnetHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Spacer()

                Button(texts.cancel) {
                    showsMagnetSheet = false
                }

                Button(texts.add) {
                    model.addMagnet(language: mainModel.language)
                    showsMagnetSheet = false
                }
                .keyboardShortcut(.defaultAction)
                .disabled(model.magnetInput.trimmingCharacters(
                    in: .whitespacesAndNewlines
                ).isEmpty)
            }
        }
        .padding(22)
        .frame(width: 520)
        .onAppear {
            DispatchQueue.main.async {
                magnetFieldIsFocused = true
            }
        }
    }

    private var serverUnavailable: some View {
        VStack(spacing: 10) {
            Image(systemName: "bolt.slash.circle")
                .font(.system(size: 30, weight: .light))
            Text(texts.serverUnavailable)
                .font(.headline)
            Text(texts.startServerFirst)
                .font(.caption)
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyLibrary: some View {
        VStack(spacing: 10) {
            Image(systemName: "tray")
                .font(.system(size: 30, weight: .light))
            Text(texts.emptyLibrary)
                .font(.headline)
            Text(texts.emptyLibraryHint)
                .font(.caption)
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func handleDrop(providers: [NSItemProvider]) -> Bool {
        var accepted = false

        for provider in providers
        where provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier) {
            accepted = true
            provider.loadItem(
                forTypeIdentifier: UTType.fileURL.identifier,
                options: nil
            ) { item, _ in
                let url: URL?
                if let value = item as? URL {
                    url = value
                } else if let data = item as? Data {
                    url = URL(dataRepresentation: data, relativeTo: nil)
                } else {
                    url = nil
                }

                guard
                    let url,
                    url.pathExtension.lowercased() == "torrent"
                else {
                    return
                }

                DispatchQueue.main.async {
                    model.addTorrentFiles([url])
                }
            }
        }
        return accepted
    }

    private func select(_ torrent: NativeTorrent) {
        model.select(
            torrent,
            extendingSelection: NSEvent.modifierFlags.contains(.command)
        )
    }

    private func handleDeleteKey() -> Bool {
        guard !showsMagnetSheet,
              model.pendingDeletionTorrents.isEmpty,
              !model.selectedTorrents.isEmpty else {
            return false
        }
        model.requestRemovalOfSelection()
        return true
    }

    private func handleReturnKey() -> Bool {
        guard !showsMagnetSheet,
              model.pendingDeletionTorrents.isEmpty else {
            return false
        }
        return model.playSelectedFirstFile(language: mainModel.language)
    }
}

private struct LibraryKeyboardShortcutMonitor: NSViewRepresentable {
    let onDelete: () -> Bool
    let onReturn: () -> Bool

    func makeCoordinator() -> Coordinator {
        Coordinator(onDelete: onDelete, onReturn: onReturn)
    }

    func makeNSView(context: Context) -> WindowTrackingView {
        let view = WindowTrackingView()
        view.windowDidChange = { [weak coordinator = context.coordinator] window in
            coordinator?.window = window
        }
        return view
    }

    func updateNSView(_ nsView: WindowTrackingView, context: Context) {
        context.coordinator.onDelete = onDelete
        context.coordinator.onReturn = onReturn
        context.coordinator.window = nsView.window
    }

    final class Coordinator {
        weak var window: NSWindow?
        var onDelete: () -> Bool
        var onReturn: () -> Bool
        private var eventMonitor: Any? = nil

        init(onDelete: @escaping () -> Bool, onReturn: @escaping () -> Bool) {
            self.onDelete = onDelete
            self.onReturn = onReturn
            eventMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) {
                [weak self] event in
                self?.handle(event) ?? event
            }
        }

        deinit {
            if let eventMonitor {
                NSEvent.removeMonitor(eventMonitor)
            }
        }

        private func handle(_ event: NSEvent) -> NSEvent? {
            guard event.window === window,
                  !isEditingText(in: event.window),
                  event.modifierFlags.intersection([.command, .control, .option]).isEmpty
            else {
                return event
            }

            switch event.keyCode {
            case 51, 117:
                return onDelete() ? nil : event
            case 36, 76:
                return onReturn() ? nil : event
            default:
                return event
            }
        }

        private func isEditingText(in window: NSWindow?) -> Bool {
            window?.firstResponder is NSTextView
                || window?.firstResponder is NSTextField
        }
    }

    final class WindowTrackingView: NSView {
        var windowDidChange: ((NSWindow?) -> Void)?

        override func viewDidMoveToWindow() {
            super.viewDidMoveToWindow()
            windowDidChange?(window)
        }
    }
}

private struct LibraryModePicker: View {
    @ObservedObject var model: LibraryViewModel
    let language: AppLanguage

    var body: some View {
        HStack(spacing: 1) {
            ForEach(LibraryDisplayMode.allCases) { mode in
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        model.setDisplayMode(mode)
                    }
                } label: {
                    Image(systemName: mode.systemImage)
                        .frame(width: 25, height: 23)
                        .background(
                            model.displayMode == mode
                                ? Color.accentColor.opacity(0.72)
                                : Color.clear,
                            in: RoundedRectangle(cornerRadius: 7)
                        )
                }
                .buttonStyle(.plain)
                .foregroundStyle(model.displayMode == mode ? Color.white : .secondary)
                .help(mode.title(language: language))
            }
        }
        .padding(2)
        .background(Color.secondary.opacity(0.10), in: RoundedRectangle(cornerRadius: 9))
    }
}

private struct TorrentContextMenu: View {
    let torrent: NativeTorrent
    @ObservedObject var model: LibraryViewModel
    let language: AppLanguage

    private var texts: LibraryTexts { LibraryTexts(language: language) }

    var body: some View {
        Button {
            model.playFirstFile(in: torrent, language: language)
        } label: {
            Label(texts.play, systemImage: "play.fill")
        }
        .disabled(torrent.playableFiles.isEmpty)

        Menu {
            ForEach(ExternalPlayerChoice.allCases) { choice in
                Button(choice.title(language: language)) {
                    model.playFirstFile(in: torrent, using: choice, language: language)
                }
            }
        } label: {
            Label(texts.openInAnotherPlayer, systemImage: "play.rectangle")
        }
        .disabled(torrent.playableFiles.isEmpty)

        Button {
            model.copyStreamURL(for: torrent)
        } label: {
            Label(texts.copyStreamURL, systemImage: "link")
        }
        .disabled(torrent.playableFiles.isEmpty)

        Button {
            model.openSource(for: torrent)
        } label: {
            Label(texts.openSource, systemImage: "safari")
        }
        .disabled(model.metadata(for: torrent)?.sourceURL == nil)

        Divider()

        Button {
            model.showFiles(for: torrent)
        } label: {
            Label(texts.showFiles, systemImage: "list.bullet.rectangle")
        }

        Button {
            model.refreshMetadata(for: torrent)
        } label: {
            Label(texts.refreshMetadata, systemImage: "arrow.clockwise")
        }

        Divider()

        Button(role: .destructive) {
            model.requestRemoval(of: torrent)
        } label: {
            Label(texts.remove, systemImage: "trash")
        }
    }
}

private struct TorrentPosterCard: View {
    let torrent: NativeTorrent
    let metadata: LibraryMetadata?
    let language: AppLanguage
    let isSelected: Bool
    let select: () -> Void
    let play: () -> Void

    private var texts: LibraryTexts { LibraryTexts(language: language) }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .bottom) {
                LibraryPoster(torrent: torrent, metadata: metadata)
                    .aspectRatio(2.0 / 3.0, contentMode: .fit)

                LinearGradient(
                    colors: [.clear, .black.opacity(0.78)],
                    startPoint: .center,
                    endPoint: .bottom
                )

                VStack(spacing: 7) {
                    HStack {
                        Text(texts.status(for: torrent))
                            .font(.caption2.weight(.semibold))
                        Spacer()
                        if let resolution = torrent.resolutionLabel {
                            Text(resolution).font(.caption2.weight(.bold))
                        }
                    }
                    .foregroundStyle(.white)

                    if torrent.stat == 2, let progress = torrent.bufferingProgress {
                        ProgressView(value: progress)
                            .tint(.orange)
                    }

                    Button(action: play) {
                        Label(texts.watch, systemImage: "play.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(.green)
                    .disabled(torrent.playableFiles.isEmpty)
                }
                .padding(10)
            }
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))

            Text(metadata?.displayTitle ?? torrent.displayTitle)
                .font(.system(size: 12.5, weight: .semibold))
                .lineLimit(2)

            HStack {
                Text(LibraryFormat.fileSize(torrent.torrentSize))
                Spacer()
                if let year = metadata?.releaseDate?.prefix(4), !year.isEmpty {
                    Text(String(year))
                }
                if let rating = metadata?.rating, rating > 0 {
                    Label(String(format: "%.1f", rating), systemImage: "star.fill")
                }
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
        .padding(9)
        .background(
            isSelected ? Color.accentColor.opacity(0.18) : Color.secondary.opacity(0.07),
            in: RoundedRectangle(cornerRadius: 16)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 1.5)
        }
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
        .onTapGesture(perform: select)
    }
}

private struct TorrentLargeCard: View {
    let torrent: NativeTorrent
    let metadata: LibraryMetadata?
    let language: AppLanguage
    let translationMode: OverviewTranslationMode
    let isSelected: Bool
    let select: () -> Void
    let play: () -> Void

    private var texts: LibraryTexts { LibraryTexts(language: language) }

    var body: some View {
        HStack(alignment: .top, spacing: 16) {
            LibraryPoster(torrent: torrent, metadata: metadata)
                .frame(width: 112, height: 164)
                .clipShape(RoundedRectangle(cornerRadius: 13, style: .continuous))

            VStack(alignment: .leading, spacing: 9) {
                HStack(alignment: .top) {
                    Text(metadata?.displayTitle ?? torrent.displayTitle)
                        .font(.title3.weight(.semibold))
                        .lineLimit(2)
                    Spacer()
                    if let resolution = torrent.resolutionLabel {
                        Text(resolution)
                            .font(.caption.weight(.bold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(.regularMaterial, in: Capsule())
                    }
                }

                if let summary = metadata?.summary, !summary.isEmpty {
                    LocalizedOverviewText(
                        sourceText: summary,
                        provider: metadata?.metadataProvider,
                        mediaID: metadata?.metadataProviderID,
                        language: language,
                        translationMode: translationMode,
                        lineLimit: 4
                    )
                }

                if let metadata {
                    HStack(spacing: 7) {
                        if let releaseDate = metadata.releaseDate, !releaseDate.isEmpty {
                            Text(releaseDate)
                        }
                        if let runtime = metadata.runtimeMinutes, runtime > 0 {
                            Text("\(runtime) min")
                        }
                        if let rating = metadata.rating, rating > 0 {
                            Label(String(format: "%.1f", rating), systemImage: "star.fill")
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }

                HStack(spacing: 8) {
                    Label("\(texts.seeds) \(torrent.connectedSeeders)", systemImage: "arrow.up.circle")
                    Label("\(texts.peers) \(max(torrent.activePeers, torrent.totalPeers))", systemImage: "person.2")
                    Label(LibraryFormat.speed(torrent.downloadSpeed), systemImage: "arrow.down.circle")
                }
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)

                if torrent.stat == 2, let progress = torrent.bufferingProgress {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(texts.buffering)
                            .font(.caption2)
                            .foregroundStyle(.orange)
                        ProgressView(value: progress).tint(.orange)
                    }
                }

                Spacer()

                HStack {
                    Text(LibraryFormat.fileSize(torrent.torrentSize))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(action: play) {
                        Label(texts.watch, systemImage: "play.fill")
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                    .tint(.green)
                    .disabled(torrent.playableFiles.isEmpty)
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, minHeight: 190, alignment: .leading)
        .background {
            let shape = RoundedRectangle(cornerRadius: 18, style: .continuous)
            ZStack {
                isSelected ? Color.accentColor.opacity(0.16) : Color.secondary.opacity(0.07)
                if let value = metadata?.backdropURL,
                   let url = URL(string: value),
                   !value.isEmpty {
                    CachedRemoteImage(
                        url: url,
                        contentMode: .fill,
                        placeholderSystemImage: "photo"
                    )
                    .opacity(0.14)
                    LinearGradient(
                        colors: [
                            Color(nsColor: .windowBackgroundColor).opacity(0.35),
                            Color(nsColor: .windowBackgroundColor).opacity(0.82)
                        ],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                }
            }
            .clipShape(shape)
        }
        .overlay {
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(isSelected ? Color.accentColor : .clear, lineWidth: 1.5)
        }
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .onTapGesture(perform: select)
    }
}

private struct LibraryPoster: View {
    let torrent: NativeTorrent
    let metadata: LibraryMetadata?

    var body: some View {
        let metadataPoster = metadata?.posterURL ?? ""
        let value = metadataPoster.isEmpty ? torrent.poster : metadataPoster
        CachedRemoteImage(
            url: value.isEmpty ? nil : URL(string: value),
            contentMode: .fill,
            placeholderSystemImage: "film"
        )
        .posterQuickLook(
            url: value.isEmpty ? nil : URL(string: value),
            title: metadata?.displayTitle ?? torrent.displayTitle
        )
    }
}

private struct TorrentLibraryRow: View {
    let torrent: NativeTorrent
    let metadata: LibraryMetadata?
    let language: AppLanguage
    let isSelected: Bool
    let action: () -> Void

    private var texts: LibraryTexts {
        LibraryTexts(language: language)
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                ZStack {
                    let posterValue = metadata?.posterURL ?? ""
                    CachedRemoteImage(
                        url: posterValue.isEmpty ? nil : URL(string: posterValue),
                        contentMode: .fill,
                        placeholderSystemImage: "film"
                    )
                        .frame(width: 40, height: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                        .posterQuickLook(
                            url: posterValue.isEmpty ? nil : URL(string: posterValue),
                            title: metadata?.displayTitle ?? torrent.displayTitle
                        )
                    if torrent.isActive {
                        Image(systemName: "play.fill")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.white)
                            .padding(6)
                            .background(Color.green.opacity(0.84), in: Circle())
                    }
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(metadata?.displayTitle ?? torrent.displayTitle)
                        .font(.system(size: 12.5, weight: .medium))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 5) {
                        Text(texts.status(for: torrent))
                        Text("·")
                        Text(LibraryFormat.fileSize(torrent.torrentSize))
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }

                Spacer(minLength: 4)

                if torrent.downloadSpeed > 0 {
                    Text(LibraryFormat.speed(torrent.downloadSpeed))
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.green)
                }
            }
            .padding(8)
            .contentShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .background(
                isSelected ? Color.accentColor.opacity(0.22) : Color.clear,
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )
        }
        .buttonStyle(.plain)
    }
}

private struct TorrentDetailView: View {
    let torrent: NativeTorrent
    @ObservedObject var model: LibraryViewModel
    let metadata: LibraryMetadata?
    let language: AppLanguage
    let translationMode: OverviewTranslationMode

    private var texts: LibraryTexts {
        LibraryTexts(language: language)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                poster

                VStack(alignment: .leading, spacing: 6) {
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(metadata?.displayTitle ?? torrent.displayTitle)
                                .font(.system(size: 18, weight: .semibold, design: .rounded))
                                .lineLimit(3)

                            if let originalTitle = metadata?.originalTitle,
                               !originalTitle.isEmpty,
                               originalTitle != metadata?.displayTitle {
                                Text(originalTitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            if let metadata {
                                Text(metadataFacts(metadata).joined(separator: " · "))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)

                                if !metadata.genres.isEmpty {
                                    Text(metadata.genres.joined(separator: " · "))
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                            } else if !torrent.category.isEmpty {
                                Text(torrent.category)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Spacer(minLength: 4)

                        Menu {
                            ForEach(ExternalPlayerChoice.allCases) { choice in
                                Button {
                                    model.setPlayer(choice, language: language)
                                } label: {
                                    if model.playerChoice == choice {
                                        Label(
                                            choice.title(language: language),
                                            systemImage: "checkmark"
                                        )
                                    } else {
                                        Text(choice.title(language: language))
                                    }
                                }
                            }
                        } label: {
                            Label(
                                model.playerChoice.title(language: language),
                                systemImage: "play.rectangle"
                            )
                        }
                        .menuStyle(.borderlessButton)
                        .fixedSize()

                        Button {
                            model.requestRemovalOfSelection()
                        } label: {
                            Image(systemName: "trash")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.red)
                        .help(texts.remove)
                    }

                    if model.resolvingMetadataHashes.contains(torrent.hash.lowercased()) {
                        HStack(spacing: 5) {
                            ProgressView().controlSize(.mini)
                            Text(texts.metadataProviderLoading)
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }

                    if let summary = metadata?.summary, !summary.isEmpty {
                        LocalizedOverviewText(
                            sourceText: summary,
                            provider: metadata?.metadataProvider,
                            mediaID: metadata?.metadataProviderID,
                            language: language,
                            translationMode: translationMode,
                            lineLimit: 3,
                            expandedMaximumHeight: 180
                        )
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            statistics

            if let progress = torrent.progress {
                VStack(spacing: 4) {
                    HStack {
                        Text(texts.downloaded)
                        Spacer()
                        Text(progress, format: .percent.precision(.fractionLength(0)))
                            .monospacedDigit()
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    ProgressView(value: progress)
                        .tint(.green)
                }
            }

            Divider()

            HStack {
                Label(texts.files, systemImage: "list.bullet.rectangle")
                    .font(.headline)
                Spacer()
                Text(texts.playerHint)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            if torrent.allFiles.isEmpty {
                VStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                    Text(texts.metadataLoading)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(torrent.allFiles, id: \.stableID) { file in
                            TorrentFileRow(
                                file: file,
                                texts: texts
                            ) {
                                model.play(file: file, language: language)
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var poster: some View {
        let shape = RoundedRectangle(cornerRadius: 12, style: .continuous)
        let metadataPoster = metadata?.posterURL ?? ""
        let posterValue = metadataPoster.isEmpty ? torrent.poster : metadataPoster

        if let url = URL(string: posterValue), !posterValue.isEmpty {
            CachedRemoteImage(url: url, contentMode: .fill, placeholderSystemImage: "film")
                .frame(width: 72, height: 96)
                .clipShape(shape)
                .posterQuickLook(
                    url: url,
                    title: metadata?.displayTitle ?? torrent.displayTitle
                )
        } else {
            posterPlaceholder
                .frame(width: 72, height: 96)
                .clipShape(shape)
        }
    }

    private var posterPlaceholder: some View {
        ZStack {
            Color.secondary.opacity(0.12)
            Image(systemName: "film")
                .font(.system(size: 24))
                .foregroundStyle(.secondary)
        }
    }

    private var statistics: some View {
        HStack(spacing: 8) {
            statBadge(
                "\(texts.seeds) \(torrent.connectedSeeders)",
                systemImage: "arrow.up.circle.fill"
            )
            statBadge(
                "\(texts.peers) \(max(torrent.activePeers, torrent.totalPeers))",
                systemImage: "person.2.fill"
            )
            statBadge(
                LibraryFormat.speed(torrent.downloadSpeed),
                systemImage: "arrow.down.circle.fill"
            )
            metadataStatusBadge
            Spacer()
            Text(texts.status(for: torrent))
                .font(.caption)
                .foregroundStyle(torrent.isActive ? Color.green : .secondary)
        }
    }

    private func metadataFacts(_ metadata: LibraryMetadata) -> [String] {
        var values: [String] = []
        if let kind = metadata.mediaKind {
            values.append(kind == .movie
                ? (language == .russian ? "Фильм" : "Movie")
                : (language == .russian ? "Сериал" : "TV"))
        }
        if let releaseDate = metadata.releaseDate, !releaseDate.isEmpty {
            values.append(releaseDate)
        }
        if let season = metadata.season {
            if let episode = metadata.episode {
                values.append(String(format: "S%02dE%02d", season, episode))
            } else {
                values.append(String(format: "S%02d", season))
            }
        }
        if let runtime = metadata.runtimeMinutes, runtime > 0 {
            values.append(language == .russian ? "\(runtime) мин" : "\(runtime) min")
        }
        if let rating = metadata.rating, rating > 0 {
            values.append("★ \(String(format: "%.1f", rating))")
        }
        return values
    }

    private func statBadge(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption)
            .monospacedDigit()
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(.regularMaterial, in: Capsule())
    }

    @ViewBuilder
    private var metadataStatusBadge: some View {
        let hash = torrent.hash.lowercased()

        if model.resolvingMetadataHashes.contains(hash) {
            Label(
                "\(texts.metadataIndicator): \(texts.metadataIndicatorLoading)",
                systemImage: "hourglass"
            )
            .foregroundStyle(.orange)
            .help(texts.metadataIndicatorLoadingHint)
            .metadataBadgeStyle()
        } else if let source = metadataSourceName {
            Label(
                "\(texts.metadataIndicator): \(source)",
                systemImage: "checkmark.seal.fill"
            )
            .foregroundStyle(.green)
            .help(texts.metadataIndicatorLoadedHint(source))
            .metadataBadgeStyle()
        } else {
            Label(
                "\(texts.metadataIndicator): \(texts.metadataIndicatorMissing)",
                systemImage: "questionmark.circle"
            )
            .foregroundStyle(.secondary)
            .help(texts.metadataIndicatorMissingHint)
            .metadataBadgeStyle()
        }
    }

    private var metadataSourceName: String? {
        if let provider = metadata?.metadataProvider {
            return provider.displayName
        }
        guard let source = metadata?.source.trimmingCharacters(in: .whitespacesAndNewlines),
              !source.isEmpty else {
            return nil
        }
        return source
    }
}

private extension View {
    func metadataBadgeStyle() -> some View {
        font(.caption)
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(.regularMaterial, in: Capsule())
    }
}

private struct TorrentFileRow: View {
    let file: NativeTorrentFile
    let texts: LibraryTexts
    let play: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: file.isPlayable ? "play.rectangle" : "doc")
                .foregroundStyle(file.isPlayable ? Color.accentColor : .secondary)
                .frame(width: 22)

            VStack(alignment: .leading, spacing: 2) {
                Text(file.displayName)
                    .font(.system(size: 12.5, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text(LibraryFormat.fileSize(file.length))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if file.isPlayable {
                Button(action: play) {
                    Label(texts.watch, systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .tint(.green)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            Color.secondary.opacity(0.07),
            in: RoundedRectangle(cornerRadius: 11, style: .continuous)
        )
    }
}

private struct LibraryTexts {
    let language: AppLanguage

    var library: String { language == .russian ? "Библиотека" : "Library" }
    var refresh: String { language == .russian ? "Обновить" : "Refresh" }
    var search: String { language == .russian ? "Поиск" : "Search" }
    var addMagnet: String { language == .russian ? "Добавить magnet-ссылку" : "Add magnet link" }
    var addTorrentFile: String { language == .russian ? "Добавить .torrent" : "Add .torrent" }
    var adding: String { language == .russian ? "Добавление…" : "Adding…" }
    var dropHint: String { language == .russian ? "Можно перетащить .torrent" : "Drop .torrent here" }
    var selectMaterial: String { language == .russian ? "Выберите материал" : "Select a material" }
    var selectMaterialHint: String {
        language == .russian
            ? "Здесь появятся файлы, статистика и кнопка запуска."
            : "Files, statistics, and playback controls will appear here."
    }
    var magnetHint: String {
        language == .russian
            ? "TorrServer получит метаданные и добавит материал в библиотеку."
            : "TorrServer will fetch metadata and add it to the library."
    }
    var cancel: String { language == .russian ? "Отмена" : "Cancel" }
    var add: String { language == .russian ? "Добавить" : "Add" }
    var serverUnavailable: String { language == .russian ? "TorrServer не запущен" : "TorrServer is stopped" }
    var startServerFirst: String {
        language == .russian
            ? "Сначала запустите сервер на вкладке «Сервер»."
            : "Start the server from the Server tab first."
    }
    var emptyLibrary: String { language == .russian ? "Библиотека пуста" : "Library is empty" }
    var emptyLibraryHint: String {
        language == .russian
            ? "Добавьте magnet-ссылку или torrent-файл."
            : "Add a magnet link or a torrent file."
    }
    var remove: String { language == .russian ? "Удалить" : "Remove" }
    func removeMaterialQuestion(count: Int) -> String {
        if count > 1 {
            return language == .russian ? "Удалить выбранные материалы?" : "Remove selected items?"
        }
        return language == .russian ? "Удалить материал?" : "Remove this item?"
    }
    func removeMaterialHint(count: Int) -> String {
        if count > 1 {
            return language == .russian
                ? "Выбранные материалы будут удалены из библиотеки TorrServer."
                : "The selected items will be removed from the TorrServer library."
        }
        return language == .russian
            ? "Материал будет удалён из библиотеки TorrServer."
            : "This item will be removed from the TorrServer library."
    }
    func selectedMaterialCount(_ count: Int) -> String {
        language == .russian
            ? "Выбрано материалов: \(count)"
            : "Selected items: \(count)"
    }
    var downloaded: String { language == .russian ? "Загружено" : "Downloaded" }
    var files: String { language == .russian ? "Файлы" : "Files" }
    var playerHint: String {
        language == .russian ? "Воспроизведение во внешнем плеере" : "Playback in an external player"
    }
    var metadataLoading: String {
        language == .russian ? "Получение метаданных torrent…" : "Fetching torrent metadata…"
    }
    var metadataProviderLoading: String {
        language == .russian ? "Получение метаданных…" : "Fetching metadata…"
    }
    var metadataIndicator: String {
        language == .russian ? "Метаданные" : "Metadata"
    }
    var metadataIndicatorLoading: String {
        language == .russian ? "загрузка" : "loading"
    }
    var metadataIndicatorMissing: String {
        language == .russian ? "нет" : "none"
    }
    var metadataIndicatorLoadingHint: String {
        language == .russian
            ? "Приложение сейчас ищет метаданные для этого материала."
            : "The app is currently looking up metadata for this item."
    }
    var metadataIndicatorMissingHint: String {
        language == .russian
            ? "Метаданные ещё не получены или материал не найден выбранным сервисом."
            : "Metadata has not been fetched yet or the selected service could not find this item."
    }
    func metadataIndicatorLoadedHint(_ provider: String) -> String {
        language == .russian
            ? "Метаданные успешно получены из \(provider)."
            : "Metadata was successfully loaded from \(provider)."
    }
    var seeds: String { language == .russian ? "Сиды" : "Seeds" }
    var peers: String { language == .russian ? "Пиры" : "Peers" }
    var watch: String { language == .russian ? "Смотреть" : "Watch" }
    var play: String { language == .russian ? "Воспроизвести" : "Play" }
    var buffering: String { language == .russian ? "Буферизация" : "Buffering" }
    var openInAnotherPlayer: String {
        language == .russian ? "Открыть в другом плеере" : "Open in another player"
    }
    var copyStreamURL: String {
        language == .russian ? "Скопировать stream URL" : "Copy stream URL"
    }
    var openSource: String {
        language == .russian ? "Открыть источник" : "Open source"
    }
    var showFiles: String {
        language == .russian ? "Показать файлы" : "Show files"
    }
    var refreshMetadata: String {
        language == .russian ? "Обновить метаданные" : "Refresh metadata"
    }

    func itemCount(_ count: Int) -> String {
        language == .russian ? "Материалов: \(count)" : "Items: \(count)"
    }

    func status(for torrent: NativeTorrent) -> String {
        switch torrent.stat {
        case 0:
            return language == .russian ? "Добавлен" : "Added"
        case 1:
            return language == .russian ? "Метаданные…" : "Metadata…"
        case 2:
            return language == .russian ? "Буферизация" : "Buffering"
        case 3:
            return language == .russian ? "Трансляция" : "Streaming"
        case 4:
            return language == .russian ? "Закрыт" : "Closed"
        case 5:
            return language == .russian ? "Готов" : "Ready"
        default:
            return torrent.statString.isEmpty ? "TorrServer" : torrent.statString
        }
    }
}

private enum LibraryFormat {
    static func fileSize(_ bytes: Int64) -> String {
        guard bytes > 0 else { return "—" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useMB, .useGB, .useTB]
        formatter.includesUnit = true
        return formatter.string(fromByteCount: bytes)
    }

    static func speed(_ bytesPerSecond: Double) -> String {
        guard bytesPerSecond > 0 else { return "0 KB/s" }
        return SpeedFormatter.string(
            bytesPerSecond: bytesPerSecond,
            unit: .automatic
        )
    }
}

private extension View {
    @ViewBuilder
    func libraryPanel() -> some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)
        if #available(macOS 26.0, *) {
            self.glassEffect(.regular, in: shape)
        } else {
            self
                .background(.regularMaterial, in: shape)
                .overlay(shape.stroke(.white.opacity(0.12), lineWidth: 0.5))
        }
    }
}
