import AppKit
import Foundation

private let jackettServerURLKey = "JackettServerURL"
private let jackettAPIKeyKey = "JackettAPIKey"

enum SearchSortField: String, CaseIterable, Identifiable {
    case seeders
    case peers
    case size

    var id: String { rawValue }
}

@MainActor
final class SearchViewModel: ObservableObject {
    @Published var serverURL: String
    @Published var apiKey: String
    @Published var query = ""
    @Published var results: [JackettSearchResult] = []
    @Published var selectedResultID: String?
    @Published var isSearching = false
    @Published var isTesting = false
    @Published var addingResultID: String?
    @Published var addedResultIDs: Set<String> = []
    @Published var connectionMessage = ""
    @Published var connectionIsHealthy = false
    @Published var showsSettings = false
    @Published var alert: LibraryAlert?
    @Published var sortField: SearchSortField = .seeders
    @Published var sortAscending = false

    var onTorrentAdded: ((String) -> Void)?

    private let jackett: JackettClient
    private let torrServer: NativeTorrServerAPI
    private let metadataStore: LibraryMetadataStore
    private let credentialStore = JackettCredentialStore()

    init(
        jackett: JackettClient = JackettClient(),
        torrServer: NativeTorrServerAPI = NativeTorrServerAPI(),
        metadataStore: LibraryMetadataStore = .shared
    ) {
        self.jackett = jackett
        self.torrServer = torrServer
        self.metadataStore = metadataStore
        serverURL = UserDefaults.standard.string(forKey: jackettServerURLKey)
            ?? "http://127.0.0.1:9117"
        let legacyAPIKey = UserDefaults.standard.string(forKey: jackettAPIKeyKey)
            ?? ""
        if let storedAPIKey = credentialStore.read(), !storedAPIKey.isEmpty {
            apiKey = storedAPIKey
        } else {
            apiKey = legacyAPIKey
            if !legacyAPIKey.isEmpty, credentialStore.save(legacyAPIKey) {
                UserDefaults.standard.removeObject(forKey: jackettAPIKeyKey)
            }
        }
    }

    var configuration: JackettConfiguration {
        JackettConfiguration(serverURL: serverURL, apiKey: apiKey)
    }

    var isConfigured: Bool {
        configuration.isComplete
    }

    var selectedResult: JackettSearchResult? {
        guard let selectedResultID else { return nil }
        return results.first { $0.id == selectedResultID }
    }

    var sortedResults: [JackettSearchResult] {
        results.sorted { left, right in
            let leftValue = sortValue(for: left)
            let rightValue = sortValue(for: right)

            if sortField == .size {
                if leftValue <= 0, rightValue > 0 { return false }
                if rightValue <= 0, leftValue > 0 { return true }
            }

            if leftValue != rightValue {
                return sortAscending
                    ? leftValue < rightValue
                    : leftValue > rightValue
            }

            if left.seeders != right.seeders {
                return left.seeders > right.seeders
            }
            return left.title.localizedCaseInsensitiveCompare(right.title)
                == .orderedAscending
        }
    }

    func saveSettings() {
        let normalizedURL = configuration.normalizedServerURL?.absoluteString
            ?? serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        serverURL = normalizedURL
        UserDefaults.standard.set(serverURL, forKey: jackettServerURLKey)
        let normalizedAPIKey = apiKey.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        if credentialStore.save(normalizedAPIKey) {
            UserDefaults.standard.removeObject(forKey: jackettAPIKeyKey)
        } else {
            UserDefaults.standard.set(normalizedAPIKey, forKey: jackettAPIKeyKey)
        }
    }

    func testConnection(language: AppLanguage, closeOnSuccess: Bool = false) {
        guard configuration.isComplete else {
            connectionIsHealthy = false
            connectionMessage = SearchTexts(language: language).enterSettings
            return
        }

        saveSettings()
        isTesting = true
        connectionMessage = ""
        Task {
            defer { isTesting = false }
            do {
                try await jackett.test(configuration: configuration)
                connectionIsHealthy = true
                connectionMessage = SearchTexts(language: language).connectionReady
                if closeOnSuccess {
                    showsSettings = false
                }
            } catch {
                connectionIsHealthy = false
                connectionMessage = error.localizedDescription
            }
        }
    }

    func search(language: AppLanguage) {
        let value = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return }
        guard configuration.isComplete else {
            showsSettings = true
            return
        }

        saveSettings()
        isSearching = true
        connectionMessage = ""
        Task {
            defer { isSearching = false }
            do {
                let values = try await jackett.search(
                    query: value,
                    configuration: configuration
                )
                results = values
                selectedResultID = sortedResults.first?.id
                connectionIsHealthy = true
            } catch {
                connectionIsHealthy = false
                alert = LibraryAlert(
                    title: "Jackett",
                    message: error.localizedDescription
                )
            }
        }
    }

    func select(_ result: JackettSearchResult) {
        selectedResultID = result.id
    }

    func toggleSortDirection() {
        sortAscending.toggle()
    }

    func add(
        _ result: JackettSearchResult,
        language: AppLanguage,
        serverIsRunning: Bool
    ) {
        guard serverIsRunning else {
            alert = LibraryAlert(
                title: "TorrServer",
                message: SearchTexts(language: language).startServerFirst
            )
            return
        }
        guard addingResultID == nil else { return }

        addingResultID = result.id
        Task {
            defer { addingResultID = nil }
            do {
                let payload = try await jackett.download(result)
                let poster = result.posterURL?.absoluteString ?? ""
                let category = result.torrServerCategory
                let torrent: NativeTorrent

                switch payload {
                case .magnet(let magnet):
                    torrent = try await torrServer.addMagnet(
                        magnet,
                        title: result.title,
                        poster: poster,
                        category: category
                    )

                case .torrent(let data, let filename):
                    let values = try await torrServer.uploadTorrent(
                        data: data,
                        filename: filename,
                        title: result.title,
                        poster: poster,
                        category: category
                    )
                    guard let value = values.first else {
                        throw AppError("TorrServer did not return the added torrent.")
                    }
                    torrent = value
                }

                let hash = torrent.hash.isEmpty ? result.infoHash : torrent.hash
                metadataStore.save(
                    LibraryMetadata(
                        title: result.title,
                        posterURL: poster,
                        summary: result.summary,
                        source: result.tracker.isEmpty ? "Jackett" : result.tracker,
                        sourceURL: result.detailsURL?.absoluteString
                    ),
                    for: hash
                )
                addedResultIDs.insert(result.id)
                onTorrentAdded?(hash)
            } catch {
                alert = LibraryAlert(
                    title: SearchTexts(language: language).couldNotAdd,
                    message: error.localizedDescription
                )
            }
        }
    }

    func openJackett() {
        guard let url = configuration.normalizedServerURL else { return }
        NSWorkspace.shared.open(url)
    }

    func installJackett() {
        guard let url = URL(string: "https://github.com/Jackett/Jackett/releases/latest") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    func openJackettProject() {
        guard let url = URL(string: "https://github.com/Jackett/Jackett") else {
            return
        }
        NSWorkspace.shared.open(url)
    }

    func openDetails(for result: JackettSearchResult) {
        guard let url = result.detailsURL else { return }
        NSWorkspace.shared.open(url)
    }

    private func sortValue(for result: JackettSearchResult) -> Int64 {
        switch sortField {
        case .seeders:
            return Int64(result.seeders)
        case .peers:
            return Int64(result.peers)
        case .size:
            return result.size
        }
    }
}

private final class JackettCredentialStore {
    private struct Payload: Codable {
        let apiKey: String
    }

    private let fileManager = FileManager.default

    private var directoryURL: URL? {
        fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            .first?
            .appendingPathComponent("TorrServer", isDirectory: true)
            .appendingPathComponent("Settings", isDirectory: true)
    }

    private var credentialsURL: URL? {
        directoryURL?.appendingPathComponent("jackett.json", isDirectory: false)
    }

    func read() -> String? {
        guard
            let credentialsURL,
            let data = try? Data(contentsOf: credentialsURL),
            let payload = try? JSONDecoder().decode(Payload.self, from: data)
        else {
            return nil
        }
        return payload.apiKey
    }

    @discardableResult
    func save(_ value: String) -> Bool {
        guard let directoryURL, let credentialsURL else { return false }

        if value.isEmpty {
            guard fileManager.fileExists(atPath: credentialsURL.path) else {
                return true
            }
            do {
                try fileManager.removeItem(at: credentialsURL)
                return true
            } catch {
                return false
            }
        }

        do {
            try fileManager.createDirectory(
                at: directoryURL,
                withIntermediateDirectories: true,
                attributes: [.posixPermissions: NSNumber(value: 0o700)]
            )
            try fileManager.setAttributes(
                [.posixPermissions: NSNumber(value: 0o700)],
                ofItemAtPath: directoryURL.path
            )
            let data = try JSONEncoder().encode(Payload(apiKey: value))
            try data.write(to: credentialsURL, options: .atomic)
            try fileManager.setAttributes(
                [.posixPermissions: NSNumber(value: 0o600)],
                ofItemAtPath: credentialsURL.path
            )
            return true
        } catch {
            return false
        }
    }
}
