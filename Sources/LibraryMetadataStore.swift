import Foundation

struct LibraryMetadata: Codable, Equatable {
    let title: String
    let posterURL: String
    let summary: String
    let source: String
}

final class LibraryMetadataStore {
    static let shared = LibraryMetadataStore()

    private let defaultsKey = "LibraryMetadataByTorrentHash"
    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
    }

    func metadata(for hash: String) -> LibraryMetadata? {
        allMetadata()[hash.lowercased()]
    }

    func save(_ metadata: LibraryMetadata, for hash: String) {
        guard !hash.isEmpty else { return }
        var values = allMetadata()
        values[hash.lowercased()] = metadata
        guard let data = try? JSONEncoder().encode(values) else { return }
        defaults.set(data, forKey: defaultsKey)
    }

    func allMetadata() -> [String: LibraryMetadata] {
        guard
            let data = defaults.data(forKey: defaultsKey),
            let values = try? JSONDecoder().decode(
                [String: LibraryMetadata].self,
                from: data
            )
        else {
            return [:]
        }
        return values
    }
}
