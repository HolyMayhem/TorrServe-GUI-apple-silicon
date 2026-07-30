import AppKit
import Foundation
import UniformTypeIdentifiers

private let libraryPlayerKey = "LibraryPreferredPlayer"
private let libraryCustomPlayerPathKey = "LibraryCustomPlayerPath"

enum ExternalPlayerChoice: String, CaseIterable, Identifiable {
    case quickTime
    case iina
    case vlc
    case systemDefault
    case custom

    var id: String { rawValue }

    func title(language: AppLanguage) -> String {
        switch self {
        case .quickTime:
            return "QuickTime"
        case .iina:
            return "IINA"
        case .vlc:
            return "VLC"
        case .systemDefault:
            return language == .russian ? "По умолчанию macOS" : "macOS Default"
        case .custom:
            return language == .russian ? "Другое приложение…" : "Other app…"
        }
    }
}

struct LibraryAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
}

@MainActor
final class LibraryViewModel: ObservableObject {
    @Published var torrents: [NativeTorrent] = []
    @Published var selectedTorrentID: String?
    @Published var searchText = ""
    @Published var magnetInput = ""
    @Published var isRefreshing = false
    @Published var isAdding = false
    @Published var isDropTargeted = false
    @Published var alert: LibraryAlert?
    @Published var playerChoice: ExternalPlayerChoice
    @Published var customPlayerPath: String

    private let api: NativeTorrServerAPI
    private var refreshTimer: Timer?

    init(api: NativeTorrServerAPI = NativeTorrServerAPI()) {
        self.api = api
        playerChoice = ExternalPlayerChoice(
            rawValue: UserDefaults.standard.string(forKey: libraryPlayerKey) ?? ""
        ) ?? .quickTime
        customPlayerPath = UserDefaults.standard.string(
            forKey: libraryCustomPlayerPathKey
        ) ?? ""
    }

    var filteredTorrents: [NativeTorrent] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !query.isEmpty else { return torrents }
        return torrents.filter {
            $0.displayTitle.localizedCaseInsensitiveContains(query)
                || $0.category.localizedCaseInsensitiveContains(query)
        }
    }

    var selectedTorrent: NativeTorrent? {
        guard let selectedTorrentID else { return nil }
        return torrents.first { $0.id == selectedTorrentID }
    }

    func startPolling() {
        guard refreshTimer == nil else { return }
        refresh()
        refreshTimer = Timer.scheduledTimer(
            withTimeInterval: 2,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refresh(silently: true)
            }
        }
    }

    func stopPolling() {
        refreshTimer?.invalidate()
        refreshTimer = nil
    }

    func refresh(silently: Bool = false) {
        guard !isRefreshing else { return }
        isRefreshing = true

        Task {
            defer { isRefreshing = false }
            do {
                let values = try await api.listTorrents()
                torrents = values

                if let selectedTorrentID,
                   !values.contains(where: { $0.id == selectedTorrentID }) {
                    self.selectedTorrentID = nil
                }
                if self.selectedTorrentID == nil {
                    self.selectedTorrentID = values.first?.id
                }
            } catch {
                if !silently {
                    showError(error)
                }
            }
        }
    }

    func select(_ torrent: NativeTorrent) {
        selectedTorrentID = torrent.id
    }

    func addMagnet(language: AppLanguage) {
        let value = magnetInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.lowercased().hasPrefix("magnet:?") else {
            alert = LibraryAlert(
                title: language == .russian ? "Неверная magnet-ссылка" : "Invalid magnet link",
                message: language == .russian
                    ? "Ссылка должна начинаться с magnet:?"
                    : "The link must start with magnet:?"
            )
            return
        }

        isAdding = true
        Task {
            defer { isAdding = false }
            do {
                let torrent = try await api.addMagnet(value)
                magnetInput = ""
                selectedTorrentID = torrent.id
                try await refreshImmediately(selectingHash: torrent.hash)
            } catch {
                showError(error)
            }
        }
    }

    func addTorrentFiles(_ urls: [URL]) {
        guard !urls.isEmpty else { return }
        isAdding = true

        Task {
            defer { isAdding = false }
            do {
                var addedHash: String?
                for url in urls where url.pathExtension.lowercased() == "torrent" {
                    let added = try await api.uploadTorrent(at: url)
                    if addedHash == nil {
                        addedHash = added.first?.hash
                    }
                }
                try await refreshImmediately(selectingHash: addedHash)
            } catch {
                showError(error)
            }
        }
    }

    func chooseTorrentFiles(language: AppLanguage) {
        let panel = NSOpenPanel()
        panel.title = language == .russian
            ? "Выберите torrent-файлы"
            : "Choose .torrent files"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = true
        if let torrentType = UTType(filenameExtension: "torrent") {
            panel.allowedContentTypes = [torrentType]
        }

        if panel.runModal() == .OK {
            addTorrentFiles(panel.urls)
        }
    }

    func removeSelected(language: AppLanguage) {
        guard let torrent = selectedTorrent else { return }

        let confirmation = NSAlert()
        confirmation.alertStyle = .warning
        confirmation.messageText = language == .russian
            ? "Удалить материал?"
            : "Remove this material?"
        confirmation.informativeText = torrent.displayTitle
        confirmation.addButton(
            withTitle: language == .russian ? "Удалить" : "Remove"
        )
        confirmation.addButton(
            withTitle: language == .russian ? "Отмена" : "Cancel"
        )

        guard confirmation.runModal() == .alertFirstButtonReturn else { return }

        Task {
            do {
                try await api.removeTorrent(hash: torrent.hash)
                selectedTorrentID = nil
                try await refreshImmediately(selectingHash: nil)
            } catch {
                showError(error)
            }
        }
    }

    func play(
        file: NativeTorrentFile,
        language: AppLanguage
    ) {
        guard
            let torrent = selectedTorrent,
            let streamURL = api.streamURL(torrent: torrent, file: file)
        else {
            return
        }

        Task {
            await api.beginPreloading(
                torrentHash: torrent.hash,
                fileID: file.id
            )
        }

        do {
            try ExternalPlayerLauncher.open(
                streamURL,
                using: playerChoice,
                customPlayerPath: customPlayerPath
            )
        } catch {
            alert = LibraryAlert(
                title: language == .russian
                    ? "Не удалось открыть плеер"
                    : "Could not open player",
                message: error.localizedDescription
            )
        }
    }

    func setPlayer(
        _ choice: ExternalPlayerChoice,
        language: AppLanguage
    ) {
        if choice == .custom {
            chooseCustomPlayer(language: language)
            return
        }

        playerChoice = choice
        UserDefaults.standard.set(choice.rawValue, forKey: libraryPlayerKey)
    }

    func chooseCustomPlayer(language: AppLanguage) {
        let panel = NSOpenPanel()
        panel.title = language == .russian
            ? "Выберите медиаплеер"
            : "Choose media player"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = [.applicationBundle]
        panel.directoryURL = URL(fileURLWithPath: "/Applications")

        guard panel.runModal() == .OK, let url = panel.url else { return }
        customPlayerPath = url.path
        playerChoice = .custom
        UserDefaults.standard.set(
            ExternalPlayerChoice.custom.rawValue,
            forKey: libraryPlayerKey
        )
        UserDefaults.standard.set(url.path, forKey: libraryCustomPlayerPathKey)
    }

    private func refreshImmediately(selectingHash: String?) async throws {
        let values = try await api.listTorrents()
        torrents = values

        if let selectingHash,
           let selected = values.first(where: { $0.hash == selectingHash }) {
            selectedTorrentID = selected.id
        } else if selectedTorrentID == nil {
            selectedTorrentID = values.first?.id
        }
    }

    private func showError(_ error: Error) {
        alert = LibraryAlert(
            title: "TorrServer",
            message: error.localizedDescription
        )
    }
}

enum ExternalPlayerLauncher {
    static func open(
        _ streamURL: URL,
        using choice: ExternalPlayerChoice,
        customPlayerPath: String
    ) throws {
        if choice == .systemDefault {
            guard NSWorkspace.shared.open(streamURL) else {
                throw AppError("macOS could not open the stream URL.")
            }
            return
        }

        let applicationURL: URL?
        switch choice {
        case .quickTime:
            applicationURL = NSWorkspace.shared.urlForApplication(
                withBundleIdentifier: "com.apple.QuickTimePlayerX"
            )
        case .iina:
            applicationURL = NSWorkspace.shared.urlForApplication(
                withBundleIdentifier: "com.colliderli.iina"
            )
        case .vlc:
            applicationURL = NSWorkspace.shared.urlForApplication(
                withBundleIdentifier: "org.videolan.vlc"
            )
        case .custom:
            applicationURL = customPlayerPath.isEmpty
                ? nil
                : URL(fileURLWithPath: customPlayerPath)
        case .systemDefault:
            applicationURL = nil
        }

        guard
            let applicationURL,
            FileManager.default.fileExists(atPath: applicationURL.path)
        else {
            throw AppError("The selected media player is not installed.")
        }

        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        NSWorkspace.shared.open(
            [streamURL],
            withApplicationAt: applicationURL,
            configuration: configuration
        ) { _, error in
            if let error {
                NSLog("Could not open stream in player: %@", error.localizedDescription)
            }
        }
    }
}
