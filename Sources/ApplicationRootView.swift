import SwiftUI

enum AppSection: String, CaseIterable, Identifiable {
    case library
    case search
    case server
    case settings

    var id: Self { self }

    func title(language: AppLanguage) -> String {
        switch self {
        case .library:
            return language == .russian ? "Библиотека" : "Library"
        case .search:
            return language == .russian ? "Поиск" : "Search"
        case .server:
            return language == .russian ? "Сервер" : "Server"
        case .settings:
            return language == .russian ? "Настройки" : "Settings"
        }
    }

    var systemImage: String {
        switch self {
        case .library: return "film.stack"
        case .search: return "magnifyingglass"
        case .server: return "network"
        case .settings: return "gearshape"
        }
    }
}

struct ApplicationRootView: View {
    @ObservedObject var mainModel: MainWindowModel
    @ObservedObject var libraryModel: LibraryViewModel
    @ObservedObject var searchModel: SearchViewModel

    @State private var columnVisibility: NavigationSplitViewVisibility = .all

    private var selection: Binding<AppSection?> {
        Binding(
            get: { mainModel.selectedSection },
            set: { section in
                guard let section, section != mainModel.selectedSection else { return }
                mainModel.selectedSection = section
                mainModel.onSectionChanged?(section)
            }
        )
    }

    var body: some View {
        NavigationSplitView(columnVisibility: $columnVisibility) {
            AppSidebarView(
                mainModel: mainModel,
                libraryModel: libraryModel,
                selection: selection
            )
            .navigationSplitViewColumnWidth(min: 220, ideal: 245, max: 285)
        } detail: {
            NavigationStack {
                detailContent
                    .navigationTitle(mainModel.selectedSection.title(language: mainModel.language))
                    .toolbar {
                        toolbarContent
                    }
            }
        }
        .frame(minWidth: 900, minHeight: 560)
        .sheet(isPresented: $libraryModel.showsPlayerSetup) {
            PlayerSetupView(
                model: libraryModel,
                language: mainModel.language
            )
        }
        .onChange(of: mainModel.jackettEnabled) { _, enabled in
            if !enabled, mainModel.selectedSection == .search {
                mainModel.selectedSection = .library
            }
        }
    }

    @ViewBuilder
    private var detailContent: some View {
        switch mainModel.selectedSection {
        case .library:
            LibraryView(
                mainModel: mainModel,
                model: libraryModel
            )
            .padding(16)
        case .search:
            SearchView(
                mainModel: mainModel,
                model: searchModel
            )
            .padding(16)
        case .server:
            MainWindowView(model: mainModel)
                .padding(16)
        case .settings:
            SettingsView(model: mainModel)
                .padding(.horizontal, 18)
        }
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        switch mainModel.selectedSection {
        case .library:
            ToolbarItemGroup {
                Button {
                    libraryModel.chooseTorrentFiles(language: mainModel.language)
                } label: {
                    Label(
                        mainModel.language == .russian ? "Добавить torrent-файл" : "Add torrent file",
                        systemImage: "doc.badge.plus"
                    )
                }
                .disabled(libraryModel.isAdding || !mainModel.canStop)
                .help(mainModel.language == .russian ? "Добавить torrent-файл" : "Add torrent file")

                Button {
                    libraryModel.showsMagnetSheet = true
                } label: {
                    Label(
                        mainModel.language == .russian ? "Добавить magnet-ссылку" : "Add magnet link",
                        systemImage: "link.badge.plus"
                    )
                }
                .disabled(libraryModel.isAdding || !mainModel.canStop)
                .help(mainModel.language == .russian ? "Добавить magnet-ссылку" : "Add magnet link")

                Picker("", selection: $libraryModel.displayMode) {
                    ForEach(LibraryDisplayMode.allCases) { mode in
                        Label(
                            mode.title(language: mainModel.language),
                            systemImage: mode.systemImage
                        )
                        .tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: libraryModel.displayMode) { _, mode in
                    libraryModel.setDisplayMode(mode)
                }
                .help(mainModel.language == .russian ? "Переключить вид библиотеки" : "Change library view")

                Button {
                    libraryModel.refresh()
                } label: {
                    Label(
                        mainModel.language == .russian ? "Обновить" : "Refresh",
                        systemImage: "arrow.clockwise"
                    )
                }
                .disabled(libraryModel.isRefreshing || !mainModel.canStop)
            }

        case .search:
            ToolbarItemGroup {
                Button {
                    searchModel.search(language: mainModel.language)
                } label: {
                    Label(
                        mainModel.language == .russian ? "Искать" : "Search",
                        systemImage: "magnifyingglass"
                    )
                }
                .disabled(
                    searchModel.isSearching
                        || searchModel.query.trimmingCharacters(
                            in: .whitespacesAndNewlines
                        ).isEmpty
                )

                Button {
                    searchModel.showsSettings = true
                } label: {
                    Label("Jackett", systemImage: "gearshape.2")
                }
            }

        case .server:
            ToolbarItemGroup {
                Button {
                    mainModel.onRefreshStorage?()
                } label: {
                    Label(
                        mainModel.language == .russian ? "Обновить" : "Refresh",
                        systemImage: "arrow.clockwise"
                    )
                }
                .disabled(mainModel.isRefreshingStorage)

                Button {
                    mainModel.onOpenWeb?()
                } label: {
                    Label("Web UI", systemImage: "safari")
                }
                .disabled(!mainModel.canOpenWeb)
                .help(mainModel.language == .russian ? "Открыть Web UI" : "Open Web UI")
            }

        case .settings:
            ToolbarItemGroup {
                Button {
                    mainModel.onDownload?()
                } label: {
                    Label(
                        mainModel.language == .russian ? "Скачать TorrServer" : "Download TorrServer",
                        systemImage: "arrow.down.circle"
                    )
                }
                .disabled(!mainModel.canDownload)
            }
        }
    }
}

private struct AppSidebarView: View {
    @ObservedObject var mainModel: MainWindowModel
    @ObservedObject var libraryModel: LibraryViewModel
    @Binding var selection: AppSection?

    private var primarySections: [AppSection] {
        mainModel.jackettEnabled
            ? [.library, .search, .server]
            : [.library, .server]
    }

    var body: some View {
        VStack(spacing: 0) {
            List(selection: $selection) {
                Section {
                    ForEach(primarySections) { section in
                        SidebarNavigationItem(
                            section: section,
                            language: mainModel.language
                        )
                    }
                }

                Section {
                    SidebarNavigationItem(
                        section: .settings,
                        language: mainModel.language
                    )
                }
            }
            .listStyle(.sidebar)
            .scrollContentBackground(.hidden)

            Divider()

            ServerStatusSidebarView(
                mainModel: mainModel,
                openServer: { selection = .server }
            )
            .padding(12)
        }
        .background(.thinMaterial)
    }
}

private struct SidebarNavigationItem: View {
    let section: AppSection
    let language: AppLanguage

    var body: some View {
        Label(section.title(language: language), systemImage: section.systemImage)
            .tag(section)
            .accessibilityLabel(section.title(language: language))
    }
}

private struct ServerStatusSidebarView: View {
    @ObservedObject var mainModel: MainWindowModel
    let openServer: () -> Void

    private var texts: Texts { Texts(language: mainModel.language) }

    private var cacheText: String {
        ByteCountFormatter.string(
            fromByteCount: mainModel.storage.cacheUsed,
            countStyle: .memory
        )
    }

    private var statusTitle: String {
        switch mainModel.statusKind {
        case .running:
            return mainModel.language == .russian ? "Запущен" : "Running"
        case .working:
            return mainModel.language == .russian ? "Запускается" : "Working"
        case .failed:
            return mainModel.language == .russian ? "Ошибка" : "Error"
        case .stopped:
            return mainModel.language == .russian ? "Остановлен" : "Stopped"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack(spacing: 8) {
                Circle()
                    .fill(mainModel.statusKind.color)
                    .frame(width: 9, height: 9)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 1) {
                    Text("TorrServer")
                        .font(.caption.weight(.semibold))
                    Text(statusTitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    mainModel.canStop ? mainModel.onStop?() : mainModel.onStart?()
                } label: {
                    if mainModel.statusKind == .working {
                        ProgressView()
                            .controlSize(.mini)
                    } else {
                        Image(systemName: mainModel.canStop ? "stop.fill" : "play.fill")
                    }
                }
                .buttonStyle(.borderless)
                .disabled(!(mainModel.canStart || mainModel.canStop))
                .help(mainModel.canStop ? texts.stop : texts.start)
                .accessibilityLabel(mainModel.canStop ? texts.stop : texts.start)
            }

            if mainModel.canStop {
                VStack(alignment: .leading, spacing: 4) {
                    Label(
                        mainModel.currentSpeedText.isEmpty
                            ? SpeedFormatter.string(bytesPerSecond: 0, unit: mainModel.speedUnit)
                            : mainModel.currentSpeedText,
                        systemImage: "arrow.down.circle"
                    )
                    Label(cacheText, systemImage: "internaldrive")
                }
                .font(.caption2.monospacedDigit())
                .foregroundStyle(.secondary)
            }

            Button {
                openServer()
            } label: {
                Label(
                    mainModel.language == .russian ? "Открыть сервер" : "Open Server",
                    systemImage: "slider.horizontal.3"
                )
                .frame(maxWidth: .infinity)
            }
            .controlSize(.small)
            .help(mainModel.language == .russian ? "Открыть настройки сервера" : "Open server settings")
        }
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
    }
}

private struct SettingsView: View {
    @ObservedObject var model: MainWindowModel

    private var texts: Texts { Texts(language: model.language) }

    var body: some View {
        Form {
            Section {
                Toggle(
                    texts.launchAtLogin,
                    isOn: setting(
                        \.launchAtLogin,
                        callback: model.onLaunchAtLoginChanged
                    )
                )
                Toggle(
                    texts.autoStartServer,
                    isOn: setting(
                        \.autoStartServer,
                        callback: model.onAutoStartChanged
                    )
                )
                Toggle(
                    texts.showSpeed,
                    isOn: setting(
                        \.showSpeed,
                        callback: model.onShowSpeedChanged
                    )
                )
                Toggle(
                    texts.hideDockIcon,
                    isOn: setting(
                        \.hideDockIcon,
                        callback: model.onHideDockIconChanged
                    )
                )
                Toggle(
                    texts.notifications,
                    isOn: setting(
                        \.notificationsEnabled,
                        callback: model.onNotificationsChanged
                    )
                )
                .disabled(model.notificationsAuthorizationPending)
            } header: {
                Text(model.language == .russian ? "Приложение" : "Application")
            }

            Section {
                Picker(texts.speedFormat, selection: $model.speedUnit) {
                    Text(texts.automaticSpeed).tag(SpeedDisplayUnit.automatic)
                    Text(texts.megabytesSpeed).tag(SpeedDisplayUnit.megabytes)
                    Text(texts.megabitsSpeed).tag(SpeedDisplayUnit.megabits)
                }
                .onChange(of: model.speedUnit) { _, unit in
                    model.onSpeedUnitChanged?(unit)
                }

                Picker(texts.languageLabel, selection: $model.language) {
                    Text(texts.russian).tag(AppLanguage.russian)
                    Text(texts.english).tag(AppLanguage.english)
                }
                .onChange(of: model.language) { _, language in
                    model.onLanguageChanged?(language)
                }

                Picker(texts.jackettSearch, selection: $model.jackettEnabled) {
                    Text("Jackett").tag(true)
                    Text("Off").tag(false)
                }
                .onChange(of: model.jackettEnabled) { _, isEnabled in
                    model.onJackettEnabledChanged?(isEnabled)
                }
            } header: {
                Text(model.language == .russian ? "Интерфейс" : "Interface")
            }

            Section {
                Picker(texts.metadataProvider, selection: $model.metadataProvider) {
                    ForEach(MetadataProvider.allCases, id: \.self) { provider in
                        Text(provider.displayName).tag(provider)
                    }
                }
                .onChange(of: model.metadataProvider) { _, provider in
                    model.onMetadataProviderChanged?(provider)
                }

                SecureField(
                    "TMDB API Key",
                    text: Binding(
                        get: { model.tmdbAPIKey },
                        set: { value in
                            model.tmdbAPIKey = value
                            model.onMetadataAPIKeyChanged?(.tmdb, value)
                        }
                    )
                )

                SecureField(
                    "OMDb API Key",
                    text: Binding(
                        get: { model.omdbAPIKey },
                        set: { value in
                            model.omdbAPIKey = value
                            model.onMetadataAPIKeyChanged?(.omdb, value)
                        }
                    )
                )

                Picker(
                    model.language == .russian ? "Перевод описаний" : "Overview translation",
                    selection: $model.overviewTranslationMode
                ) {
                    Text(model.language == .russian ? "Автоматически" : "Automatic")
                        .tag(OverviewTranslationMode.automatic)
                    Text(model.language == .russian ? "Оригинал" : "Original")
                        .tag(OverviewTranslationMode.original)
                }
                .onChange(of: model.overviewTranslationMode) { _, mode in
                    model.onOverviewTranslationModeChanged?(mode)
                }
            } header: {
                Text(model.language == .russian ? "Метаданные" : "Metadata")
            } footer: {
                Text(model.language == .russian
                    ? "Ключи хранятся локально и используются только для получения постеров и описаний."
                    : "Keys are stored locally and used only to fetch posters and descriptions.")
            }
        }
        .formStyle(.grouped)
    }

    private func setting(
        _ keyPath: ReferenceWritableKeyPath<MainWindowModel, Bool>,
        callback: ((Bool) -> Void)?
    ) -> Binding<Bool> {
        Binding(
            get: { model[keyPath: keyPath] },
            set: { value in
                model[keyPath: keyPath] = value
                callback?(value)
            }
        )
    }
}

private struct PlayerSetupView: View {
    @ObservedObject var model: LibraryViewModel
    let language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image(systemName: "play.rectangle.on.rectangle")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 3) {
                    Text(language == .russian ? "Выберите основной плеер" : "Choose your default player")
                        .font(.title3.weight(.semibold))
                    Text(language == .russian
                        ? "Его можно изменить в библиотеке в любое время."
                        : "You can change it from the library at any time.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(spacing: 8) {
                setupPlayerRow(
                    choice: .quickTime,
                    installed: true
                )
                ForEach(model.detectedPlayers) { player in
                    setupPlayerRow(
                        choice: player.choice,
                        installed: player.isInstalled
                    )
                }
            }

            HStack {
                Spacer()
                Button(language == .russian ? "Позже" : "Later") {
                    model.dismissPlayerSetup()
                }
            }
        }
        .padding(24)
        .frame(width: 470)
    }

    private func setupPlayerRow(
        choice: ExternalPlayerChoice,
        installed: Bool
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: choice == .quickTime ? "play.rectangle" : "play.square")
                .frame(width: 28)
                .foregroundStyle(installed ? Color.accentColor : Color.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(choice.title(language: language)).font(.headline)
                Text(installed
                    ? (language == .russian ? "Установлен" : "Installed")
                    : (language == .russian ? "Не установлен" : "Not installed"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if installed {
                Button(language == .russian ? "Выбрать" : "Select") {
                    model.setPlayer(choice, language: language)
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button(language == .russian ? "Скачать" : "Download") {
                    model.download(choice)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(12)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }
}
