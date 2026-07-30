import AppKit
import SwiftUI
import UniformTypeIdentifiers

struct LibraryView: View {
    @ObservedObject var mainModel: MainWindowModel
    @ObservedObject var model: LibraryViewModel
    @State private var showsMagnetSheet = false

    private var texts: LibraryTexts {
        LibraryTexts(language: mainModel.language)
    }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor).opacity(0.36),
                    Color.green.opacity(0.045),
                    Color(nsColor: .windowBackgroundColor).opacity(0.22)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 12) {
                header
                libraryContent
            }
            .padding(.horizontal, 17)
            .padding(.top, 6)
            .padding(.bottom, 17)
        }
        .frame(width: 920, height: 640)
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
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("TorrServer")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                Text("Holy Mayhem")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            AppSectionPicker(model: mainModel)

            Spacer()

            HStack(spacing: 7) {
                Circle()
                    .fill(mainModel.statusKind.color)
                    .frame(width: 10, height: 10)
                    .shadow(
                        color: mainModel.statusKind.color.opacity(0.45),
                        radius: 4
                    )

                Text(mainModel.statusText)
                    .font(.system(size: 12.5, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
            .libraryGlass(in: Capsule())
        }
    }

    private var libraryContent: some View {
        HStack(spacing: 12) {
            torrentListPanel
                .frame(width: 314)

            torrentDetailPanel
                .frame(maxWidth: .infinity)
        }
        .frame(maxHeight: .infinity)
    }

    private var torrentListPanel: some View {
        VStack(spacing: 10) {
            HStack {
                Label(texts.library, systemImage: "film.stack")
                    .font(.headline)

                Spacer()

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
                                language: mainModel.language,
                                isSelected: model.selectedTorrentID == torrent.id
                            ) {
                                model.select(torrent)
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

    @ViewBuilder
    private var torrentDetailPanel: some View {
        if let torrent = model.selectedTorrent {
            TorrentDetailView(
                torrent: torrent,
                model: model,
                language: mainModel.language
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
}

private struct TorrentLibraryRow: View {
    let torrent: NativeTorrent
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
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(
                            torrent.isActive
                                ? Color.green.opacity(0.18)
                                : Color.secondary.opacity(0.12)
                        )
                        .frame(width: 40, height: 40)
                    Image(systemName: torrent.isActive ? "play.fill" : "film")
                        .foregroundStyle(torrent.isActive ? Color.green : .secondary)
                }

                VStack(alignment: .leading, spacing: 3) {
                    Text(torrent.displayTitle)
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
    let language: AppLanguage

    private var texts: LibraryTexts {
        LibraryTexts(language: language)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                poster

                VStack(alignment: .leading, spacing: 6) {
                    Text(torrent.displayTitle)
                        .font(.system(size: 18, weight: .semibold, design: .rounded))
                        .lineLimit(3)

                    if !torrent.category.isEmpty {
                        Text(torrent.category)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text(LibraryFormat.fileSize(torrent.torrentSize))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

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

                Button(role: .destructive) {
                    model.removeSelected(language: language)
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.plain)
                .foregroundStyle(.red)
                .help(texts.remove)
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

        if let url = URL(string: torrent.poster), !torrent.poster.isEmpty {
            AsyncImage(url: url) { image in
                image
                    .resizable()
                    .scaledToFill()
            } placeholder: {
                posterPlaceholder
            }
            .frame(width: 72, height: 96)
            .clipShape(shape)
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
            Spacer()
            Text(texts.status(for: torrent))
                .font(.caption)
                .foregroundStyle(torrent.isActive ? Color.green : .secondary)
        }
    }

    private func statBadge(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(.caption)
            .monospacedDigit()
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
    var downloaded: String { language == .russian ? "Загружено" : "Downloaded" }
    var files: String { language == .russian ? "Файлы" : "Files" }
    var playerHint: String {
        language == .russian ? "Воспроизведение во внешнем плеере" : "Playback in an external player"
    }
    var metadataLoading: String {
        language == .russian ? "Получение метаданных torrent…" : "Fetching torrent metadata…"
    }
    var seeds: String { language == .russian ? "Сиды" : "Seeds" }
    var peers: String { language == .russian ? "Пиры" : "Peers" }
    var watch: String { language == .russian ? "Смотреть" : "Watch" }

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
    func libraryGlass<S: Shape>(in shape: S) -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(.regular, in: shape)
        } else {
            self.background(.regularMaterial, in: shape)
                .overlay(shape.stroke(.white.opacity(0.12), lineWidth: 0.5))
        }
    }

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
