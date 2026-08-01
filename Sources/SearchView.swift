import SwiftUI

struct SearchView: View {
    @ObservedObject var mainModel: MainWindowModel
    @ObservedObject var model: SearchViewModel

    private var texts: SearchTexts {
        SearchTexts(language: mainModel.language)
    }

    var body: some View {
        Group {
            if model.isConfigured {
                searchContent
            } else {
                setupContent
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .sheet(isPresented: $model.showsSettings) {
            settingsSheet
        }
        .alert(item: $model.alert) { alert in
            Alert(
                title: Text(alert.title),
                message: Text(alert.message),
                dismissButton: .default(Text("OK"))
            )
        }
    }

    private var searchContent: some View {
        VStack(spacing: 12) {
            searchBar

            HStack(spacing: 12) {
                resultsPanel
                    .frame(width: 400)
                resultDetailPanel
                    .frame(maxWidth: .infinity)
            }
        }
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField(texts.searchPlaceholder, text: $model.query)
                    .textFieldStyle(.plain)
                    .onSubmit {
                        model.search(language: mainModel.language)
                    }

                if !model.query.isEmpty {
                    Button {
                        model.query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .frame(height: 38)
            .background(
                Color.secondary.opacity(0.10),
                in: RoundedRectangle(cornerRadius: 12, style: .continuous)
            )

            Button {
                model.search(language: mainModel.language)
            } label: {
                HStack(spacing: 7) {
                    if model.isSearching {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Image(systemName: "magnifyingglass")
                    }
                    Text(texts.find)
                }
                .frame(minWidth: 78)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(
                model.isSearching
                    || model.query.trimmingCharacters(
                        in: .whitespacesAndNewlines
                    ).isEmpty
            )

            Button {
                model.showsSettings = true
            } label: {
                Label("Jackett", systemImage: "gearshape")
                    .font(.system(size: 12.5, weight: .medium))
            }
            .buttonStyle(.bordered)
            .controlSize(.large)
        }
        .padding(10)
        .searchPanel()
    }

    private var resultsPanel: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label(texts.results, systemImage: "list.bullet.rectangle")
                    .font(.headline)
                Spacer()

                if !model.results.isEmpty {
                    sortMenu
                }

                if !model.results.isEmpty {
                    Text("\(model.results.count)")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }

            if model.isSearching && model.results.isEmpty {
                searchLoading
            } else if model.results.isEmpty {
                searchEmpty
            } else {
                ScrollView {
                    LazyVStack(spacing: 6) {
                        ForEach(model.sortedResults) { result in
                            SearchResultRow(
                                result: result,
                                isSelected: model.selectedResultID == result.id,
                                isAdded: model.addedResultIDs.contains(result.id),
                                texts: texts
                            ) {
                                model.select(result)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .padding(14)
        .searchPanel()
    }

    private var sortMenu: some View {
        Menu {
            ForEach(SearchSortField.allCases) { field in
                Button {
                    model.sortField = field
                } label: {
                    if model.sortField == field {
                        Label(
                            texts.sortTitle(for: field),
                            systemImage: "checkmark"
                        )
                    } else {
                        Text(texts.sortTitle(for: field))
                    }
                }
            }

            Divider()

            Button {
                model.toggleSortDirection()
            } label: {
                Label(
                    model.sortAscending
                        ? texts.ascending
                        : texts.descending,
                    systemImage: model.sortAscending
                        ? "arrow.up"
                        : "arrow.down"
                )
            }
        } label: {
            Label(
                texts.sortTitle(for: model.sortField),
                systemImage: model.sortAscending ? "arrow.up" : "arrow.down"
            )
            .font(.caption)
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help(texts.sort)
    }

    @ViewBuilder
    private var resultDetailPanel: some View {
        if let result = model.selectedResult {
            SearchResultDetail(
                result: result,
                model: model,
                texts: texts,
                language: mainModel.language,
                serverIsRunning: mainModel.canStop
            )
            .padding(16)
            .searchPanel()
        } else {
            VStack(spacing: 12) {
                Image(systemName: "sparkle.magnifyingglass")
                    .font(.system(size: 42, weight: .light))
                    .foregroundStyle(.secondary)
                Text(texts.selectResult)
                    .font(.headline)
                Text(texts.selectResultHint)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(14)
            .searchPanel()
        }
    }

    private var searchLoading: some View {
        VStack(spacing: 12) {
            ProgressView()
            Text(texts.searching)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var searchEmpty: some View {
        VStack(spacing: 11) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 34, weight: .light))
            Text(texts.startSearching)
                .font(.headline)
            Text(texts.startSearchingHint)
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .foregroundStyle(.secondary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var setupContent: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.15))
                    .frame(width: 76, height: 76)
                Image(systemName: "sparkle.magnifyingglass")
                    .font(.system(size: 32, weight: .medium))
                    .foregroundStyle(Color.accentColor)
            }

            VStack(spacing: 6) {
                Text(texts.connectJackett)
                    .font(.system(size: 22, weight: .semibold, design: .rounded))
                Text(texts.connectJackettHint)
                    .font(.callout)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .frame(maxWidth: 540)
            }

            configurationFields
                .frame(width: 540)

            HStack {
                Button(texts.openProject) {
                    model.openJackettProject()
                }
                .buttonStyle(.bordered)

                Button {
                    model.testConnection(
                        language: mainModel.language,
                        closeOnSuccess: false
                    )
                } label: {
                    if model.isTesting {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        Label(texts.connect, systemImage: "bolt.horizontal")
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.isTesting || !model.configuration.isComplete)
            }

            connectionStatus
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(28)
        .searchPanel()
    }

    private var settingsSheet: some View {
        VStack(alignment: .leading, spacing: 17) {
            HStack {
                Label(texts.jackettSettings, systemImage: "gearshape.2")
                    .font(.title3.weight(.semibold))
                Spacer()
                Button {
                    model.showsSettings = false
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }

            Text(texts.settingsHint)
                .font(.caption)
                .foregroundStyle(.secondary)

            configurationFields
            connectionStatus

            HStack {
                Button(texts.openJackett) {
                    model.openJackett()
                }
                .disabled(model.configuration.normalizedServerURL == nil)

                Spacer()

                Button(texts.saveAndCheck) {
                    model.testConnection(
                        language: mainModel.language,
                        closeOnSuccess: true
                    )
                }
                .keyboardShortcut(.defaultAction)
                .disabled(model.isTesting || !model.configuration.isComplete)
            }
        }
        .padding(22)
        .frame(width: 520)
    }

    private var configurationFields: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 5) {
                Text(texts.jackettAddress)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                TextField("http://127.0.0.1:9117", text: $model.serverURL)
                    .textFieldStyle(.roundedBorder)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(texts.apiKey)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                SecureField(texts.apiKeyPlaceholder, text: $model.apiKey)
                    .textFieldStyle(.roundedBorder)
            }
        }
    }

    @ViewBuilder
    private var connectionStatus: some View {
        if !model.connectionMessage.isEmpty {
            Label(
                model.connectionMessage,
                systemImage: model.connectionIsHealthy
                    ? "checkmark.circle.fill"
                    : "exclamationmark.triangle.fill"
            )
            .font(.caption)
            .foregroundStyle(
                model.connectionIsHealthy ? Color.green : Color.orange
            )
            .lineLimit(2)
        }
    }
}

private struct SearchResultRow: View {
    let result: JackettSearchResult
    let isSelected: Bool
    let isAdded: Bool
    let texts: SearchTexts
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                poster

                VStack(alignment: .leading, spacing: 4) {
                    Text(result.title)
                        .font(.system(size: 12.5, weight: .medium))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)

                    HStack(spacing: 6) {
                        Label("\(result.seeders)", systemImage: "arrow.up")
                            .foregroundStyle(result.seeders > 0 ? Color.green : .secondary)
                        Label("\(result.peers)", systemImage: "person.2")
                            .foregroundStyle(result.peers > 0 ? Color.blue : .secondary)
                        Text(SearchFormat.fileSize(result.size))
                        if !result.tracker.isEmpty {
                            Text(result.tracker)
                                .lineLimit(1)
                        }
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }

                Spacer(minLength: 3)
                if isAdded {
                    Image(systemName: "checkmark.circle.fill")
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

    @ViewBuilder
    private var poster: some View {
        let shape = RoundedRectangle(cornerRadius: 8, style: .continuous)
        if let url = result.posterURL {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                posterPlaceholder
            }
            .frame(width: 38, height: 50)
            .clipShape(shape)
        } else {
            posterPlaceholder
                .frame(width: 38, height: 50)
                .clipShape(shape)
        }
    }

    private var posterPlaceholder: some View {
        ZStack {
            Color.secondary.opacity(0.12)
            Image(systemName: "film")
                .foregroundStyle(.secondary)
        }
    }
}

private struct SearchResultDetail: View {
    let result: JackettSearchResult
    @ObservedObject var model: SearchViewModel
    let texts: SearchTexts
    let language: AppLanguage
    let serverIsRunning: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 14) {
                poster

                VStack(alignment: .leading, spacing: 7) {
                    Text(result.title)
                        .font(.system(size: 19, weight: .semibold, design: .rounded))
                        .lineLimit(4)
                        .fixedSize(horizontal: false, vertical: true)

                    HStack(spacing: 8) {
                        if !result.year.isEmpty {
                            badge(result.year, image: "calendar")
                        }
                        badge(
                            SearchFormat.fileSize(result.size),
                            image: "internaldrive"
                        )
                    }

                    if !result.tracker.isEmpty {
                        Label(result.tracker, systemImage: "dot.radiowaves.left.and.right")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                Spacer()
            }

            HStack(spacing: 8) {
                statistic(
                    title: texts.seeds,
                    value: "\(result.seeders)",
                    image: "arrow.up.circle.fill",
                    color: .green
                )
                statistic(
                    title: texts.peers,
                    value: "\(result.peers)",
                    image: "person.2.fill",
                    color: .blue
                )
                Spacer()
            }

            Divider()

            Text(texts.description)
                .font(.headline)

            if result.summary.isEmpty {
                Text(texts.noDescription)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            } else {
                ScrollView {
                    Text(result.summary)
                        .font(.callout)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .textSelection(.enabled)
                }
            }

            Spacer(minLength: 0)

            if !serverIsRunning {
                Label(texts.startServerFirst, systemImage: "bolt.slash")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }

            HStack {
                if result.detailsURL != nil {
                    Button(texts.openSource) {
                        model.openDetails(for: result)
                    }
                    .buttonStyle(.bordered)
                }

                Spacer()

                Button {
                    model.add(
                        result,
                        language: language,
                        serverIsRunning: serverIsRunning
                    )
                } label: {
                    if model.addingResultID == result.id {
                        HStack {
                            ProgressView()
                                .controlSize(.small)
                            Text(texts.adding)
                        }
                    } else if model.addedResultIDs.contains(result.id) {
                        Label(texts.added, systemImage: "checkmark")
                    } else {
                        Label(texts.addToLibrary, systemImage: "plus")
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(
                    model.addedResultIDs.contains(result.id)
                        ? Color.green
                        : Color.accentColor
                )
                .disabled(
                    model.addingResultID != nil
                        || model.addedResultIDs.contains(result.id)
                        || !serverIsRunning
                )
            }
        }
    }

    @ViewBuilder
    private var poster: some View {
        let shape = RoundedRectangle(cornerRadius: 14, style: .continuous)
        if let url = result.posterURL {
            AsyncImage(url: url) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                posterPlaceholder
            }
            .frame(width: 112, height: 154)
            .clipShape(shape)
        } else {
            posterPlaceholder
                .frame(width: 112, height: 154)
                .clipShape(shape)
        }
    }

    private var posterPlaceholder: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color.accentColor.opacity(0.18),
                    Color.secondary.opacity(0.08)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            Image(systemName: "film.stack")
                .font(.system(size: 34, weight: .light))
                .foregroundStyle(.secondary)
        }
    }

    private func badge(_ title: String, image: String) -> some View {
        Label(title, systemImage: image)
            .font(.caption)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(.regularMaterial, in: Capsule())
    }

    private func statistic(
        title: String,
        value: String,
        image: String,
        color: Color
    ) -> some View {
        HStack(spacing: 7) {
            Image(systemName: image)
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 14, weight: .semibold).monospacedDigit())
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(Color.secondary.opacity(0.08), in: Capsule())
    }
}

struct SearchTexts {
    let language: AppLanguage

    var find: String { language == .russian ? "Найти" : "Search" }
    var searchPlaceholder: String {
        language == .russian
            ? "Название фильма или сериала"
            : "Movie or series title"
    }
    var results: String { language == .russian ? "Результаты" : "Results" }
    var sort: String { language == .russian ? "Сортировка" : "Sort" }
    var ascending: String {
        language == .russian ? "По возрастанию" : "Ascending"
    }
    var descending: String {
        language == .russian ? "По убыванию" : "Descending"
    }
    func sortTitle(for field: SearchSortField) -> String {
        switch field {
        case .seeders:
            return language == .russian ? "Сиды" : "Seeders"
        case .peers:
            return language == .russian ? "Пиры" : "Peers"
        case .size:
            return language == .russian ? "Размер" : "Size"
        }
    }
    var searching: String { language == .russian ? "Поиск в Jackett…" : "Searching Jackett…" }
    var startSearching: String { language == .russian ? "Найдите фильм" : "Find something to watch" }
    var startSearchingHint: String {
        language == .russian
            ? "Jackett выполнит поиск по подключённым торрент-трекерам."
            : "Jackett will search your configured torrent indexers."
    }
    var selectResult: String { language == .russian ? "Выберите раздачу" : "Select a release" }
    var selectResultHint: String {
        language == .russian
            ? "Здесь появятся описание, обложка и кнопка добавления."
            : "Poster, description, and add controls will appear here."
    }
    var connectJackett: String { language == .russian ? "Подключите Jackett" : "Connect Jackett" }
    var connectJackettHint: String {
        language == .russian
            ? "Укажите адрес и API-ключ из панели Jackett. После этого поиск будет работать прямо внутри TorrServer."
            : "Enter the address and API key from Jackett. Search will then work directly inside TorrServer."
    }
    var jackettAddress: String { language == .russian ? "Адрес Jackett" : "Jackett address" }
    var apiKey: String { "API key" }
    var apiKeyPlaceholder: String {
        language == .russian ? "API-ключ из Jackett" : "API key from Jackett"
    }
    var connect: String { language == .russian ? "Подключить" : "Connect" }
    var openProject: String {
        language == .russian ? "Открыть проект Jackett" : "Open Jackett project"
    }
    var connectionReady: String {
        language == .russian ? "Jackett подключён и готов к поиску." : "Jackett is connected and ready."
    }
    var enterSettings: String {
        language == .russian ? "Укажите адрес и API-ключ Jackett." : "Enter the Jackett address and API key."
    }
    var jackettSettings: String { language == .russian ? "Настройки Jackett" : "Jackett Settings" }
    var settingsHint: String {
        language == .russian
            ? "API-ключ находится в верхней части панели Jackett."
            : "The API key is shown near the top of the Jackett dashboard."
    }
    var openJackett: String { language == .russian ? "Открыть Jackett" : "Open Jackett" }
    var saveAndCheck: String {
        language == .russian ? "Сохранить и проверить" : "Save & Test"
    }
    var seeds: String { language == .russian ? "Сиды" : "Seeders" }
    var peers: String { language == .russian ? "Пиры" : "Peers" }
    var description: String { language == .russian ? "Описание" : "Description" }
    var noDescription: String {
        language == .russian
            ? "Этот трекер не передал описание. Название, размер и статистика раздачи всё равно доступны."
            : "This indexer did not provide a description. Release name, size, and swarm stats are still available."
    }
    var openSource: String { language == .russian ? "Открыть источник" : "Open Source" }
    var addToLibrary: String {
        language == .russian ? "Добавить в библиотеку" : "Add to Library"
    }
    var adding: String { language == .russian ? "Добавление…" : "Adding…" }
    var added: String { language == .russian ? "Добавлено" : "Added" }
    var startServerFirst: String {
        language == .russian
            ? "Сначала запустите TorrServer на вкладке «Сервер»."
            : "Start TorrServer from the Server tab first."
    }
    var couldNotAdd: String {
        language == .russian ? "Не удалось добавить раздачу" : "Could not add release"
    }
}

private enum SearchFormat {
    static func fileSize(_ bytes: Int64) -> String {
        guard bytes > 0 else { return "—" }
        let formatter = ByteCountFormatter()
        formatter.countStyle = .file
        formatter.allowedUnits = [.useMB, .useGB, .useTB]
        return formatter.string(fromByteCount: bytes)
    }
}

private extension View {
    @ViewBuilder
    func searchPanel() -> some View {
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
