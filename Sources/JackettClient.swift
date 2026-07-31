import Foundation

struct JackettConfiguration: Equatable {
    var serverURL: String
    var apiKey: String

    var normalizedServerURL: URL? {
        var value = serverURL.trimmingCharacters(in: .whitespacesAndNewlines)
        while value.hasSuffix("/") {
            value.removeLast()
        }
        guard
            let url = URL(string: value),
            ["http", "https"].contains(url.scheme?.lowercased() ?? ""),
            url.host != nil
        else {
            return nil
        }
        return url
    }

    var isComplete: Bool {
        normalizedServerURL != nil
            && !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

struct JackettSearchResult: Identifiable, Equatable {
    let id: String
    let title: String
    let summary: String
    let tracker: String
    let downloadURL: URL?
    let magnetURL: URL?
    let posterURL: URL?
    let detailsURL: URL?
    let size: Int64
    let seeders: Int
    let peers: Int
    let categories: [String]
    let publishedAt: Date?
    let infoHash: String
    let year: String

    var bestDownloadURL: URL? {
        magnetURL ?? downloadURL
    }

    var torrServerCategory: String {
        if categories.contains(where: { $0.hasPrefix("2") }) {
            return "movie"
        }
        if categories.contains(where: { $0.hasPrefix("5") }) {
            return "tv"
        }
        return "other"
    }
}

enum JackettDownloadPayload {
    case magnet(String)
    case torrent(data: Data, filename: String)
}

final class JackettClient {
    private let session: URLSession

    init(session: URLSession = .shared) {
        self.session = session
    }

    func test(configuration: JackettConfiguration) async throws {
        let url = try endpoint(
            configuration: configuration,
            queryItems: [
                URLQueryItem(name: "t", value: "caps")
            ]
        )
        let (data, response) = try await session.data(from: url)
        try validate(response: response, data: data)
        guard data.range(of: Data("<caps".utf8)) != nil else {
            throw AppError("Jackett returned an unexpected response.")
        }
    }

    func search(
        query: String,
        configuration: JackettConfiguration
    ) async throws -> [JackettSearchResult] {
        let items = [
            URLQueryItem(name: "t", value: "search"),
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "limit", value: "100")
        ]

        let url = try endpoint(
            configuration: configuration,
            queryItems: items
        )
        let (data, response) = try await session.data(from: url)
        try validate(response: response, data: data)

        let parser = JackettTorznabParser(data: data)
        let results = try parser.parse()
        return results
            .filter { $0.bestDownloadURL != nil }
            .sorted { left, right in
                if left.seeders != right.seeders {
                    return left.seeders > right.seeders
                }
                return left.publishedAt ?? .distantPast
                    > right.publishedAt ?? .distantPast
            }
    }

    func download(_ result: JackettSearchResult) async throws -> JackettDownloadPayload {
        guard let url = result.bestDownloadURL else {
            throw AppError("Jackett did not provide a torrent or magnet link.")
        }
        if url.scheme?.lowercased() == "magnet" {
            return .magnet(url.absoluteString)
        }

        let (data, response) = try await session.data(from: url)
        try validate(response: response, data: data)

        if
            let text = String(data: data, encoding: .utf8)?
                .trimmingCharacters(in: .whitespacesAndNewlines),
            text.lowercased().hasPrefix("magnet:?")
        {
            return .magnet(text)
        }

        guard data.count > 16 else {
            throw AppError("Jackett returned an empty torrent file.")
        }
        return .torrent(
            data: data,
            filename: sanitizedTorrentFilename(result.title)
        )
    }

    private func endpoint(
        configuration: JackettConfiguration,
        queryItems: [URLQueryItem]
    ) throws -> URL {
        guard let serverURL = configuration.normalizedServerURL else {
            throw AppError("Enter a valid Jackett address.")
        }
        var components = URLComponents(
            url: serverURL
                .appendingPathComponent("api/v2.0/indexers/all/results/torznab/api"),
            resolvingAgainstBaseURL: false
        )
        components?.queryItems = [
            URLQueryItem(
                name: "apikey",
                value: configuration.apiKey.trimmingCharacters(
                    in: .whitespacesAndNewlines
                )
            )
        ] + queryItems
        guard let url = components?.url else {
            throw AppError("Could not create the Jackett API URL.")
        }
        return url
    }

    private func validate(response: URLResponse, data: Data) throws {
        guard
            let response = response as? HTTPURLResponse,
            200..<300 ~= response.statusCode
        else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? 0
            throw AppError("Jackett returned HTTP \(status).")
        }

        if
            let text = String(data: data, encoding: .utf8),
            text.contains("<error "),
            let message = JackettTorznabParser.errorMessage(in: data)
        {
            throw AppError(message)
        }
    }

    private func sanitizedTorrentFilename(_ title: String) -> String {
        let invalid = CharacterSet(charactersIn: "/:\\?%*|\"<>")
        let value = title
            .components(separatedBy: invalid)
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(value.isEmpty ? "download" : value).torrent"
    }
}

final class JackettTorznabParser: NSObject, XMLParserDelegate {
    private struct Draft {
        var title = ""
        var guid = ""
        var summary = ""
        var tracker = ""
        var link = ""
        var enclosure = ""
        var magnet = ""
        var poster = ""
        var details = ""
        var size: Int64 = 0
        var seeders = 0
        var peers = 0
        var categories: [String] = []
        var publishedAt: Date?
        var infoHash = ""
        var year = ""
    }

    private let data: Data
    private var results: [JackettSearchResult] = []
    private var draft: Draft?
    private var elementName = ""
    private var characters = ""
    private var parserError: Error?

    init(data: Data) {
        self.data = data
    }

    func parse() throws -> [JackettSearchResult] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        guard parser.parse() else {
            throw parserError
                ?? parser.parserError
                ?? AppError("Jackett returned invalid XML.")
        }
        return results
    }

    static func errorMessage(in data: Data) -> String? {
        guard
            let value = String(data: data, encoding: .utf8),
            let range = value.range(
                of: #"description="([^"]+)""#,
                options: .regularExpression
            )
        else {
            return nil
        }
        let match = String(value[range])
        return match
            .replacingOccurrences(of: #"description=""#, with: "")
            .dropLast()
            .description
    }

    func parser(
        _ parser: XMLParser,
        didStartElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?,
        attributes attributeDict: [String: String] = [:]
    ) {
        self.elementName = elementName
        characters = ""

        if elementName == "item" {
            draft = Draft()
            return
        }
        guard draft != nil else { return }

        if elementName == "enclosure" {
            draft?.enclosure = attributeDict["url"] ?? ""
            if let length = attributeDict["length"] {
                draft?.size = Int64(length) ?? draft?.size ?? 0
            }
        } else if elementName == "attr" || elementName.hasSuffix(":attr") {
            applyAttribute(
                name: attributeDict["name"] ?? "",
                value: attributeDict["value"] ?? ""
            )
        }
    }

    func parser(
        _ parser: XMLParser,
        foundCharacters string: String
    ) {
        characters += string
    }

    func parser(
        _ parser: XMLParser,
        didEndElement elementName: String,
        namespaceURI: String?,
        qualifiedName qName: String?
    ) {
        guard var value = draft else { return }
        let text = characters.trimmingCharacters(in: .whitespacesAndNewlines)

        switch elementName {
        case "title": value.title = text
        case "guid": value.guid = text
        case "description": value.summary = Self.plainText(text)
        case "jackettindexer": value.tracker = text
        case "link": value.link = text
        case "comments": value.details = text
        case "size": value.size = Int64(text) ?? value.size
        case "category":
            if !text.isEmpty {
                value.categories.append(text)
            }
        case "pubDate": value.publishedAt = Self.parseDate(text)
        case "item":
            results.append(Self.result(from: value))
            draft = nil
            characters = ""
            return
        default:
            break
        }

        draft = value
        characters = ""
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) {
        parserError = parseError
    }

    private func applyAttribute(name: String, value: String) {
        switch name.lowercased() {
        case "seeders": draft?.seeders = Int(value) ?? 0
        case "peers": draft?.peers = Int(value) ?? 0
        case "coverurl": draft?.poster = value
        case "magneturl": draft?.magnet = value
        case "infohash": draft?.infoHash = value
        case "year": draft?.year = value
        case "category":
            if !value.isEmpty {
                draft?.categories.append(value)
            }
        default:
            break
        }
    }

    private static func result(from value: Draft) -> JackettSearchResult {
        let linkURL = URL(string: value.enclosure.isEmpty ? value.link : value.enclosure)
        let directMagnet = URL(string: value.magnet)
        let downloadURL: URL?
        let magnetURL: URL?

        if linkURL?.scheme?.lowercased() == "magnet" {
            downloadURL = nil
            magnetURL = directMagnet ?? linkURL
        } else {
            downloadURL = linkURL
            magnetURL = directMagnet
        }

        return JackettSearchResult(
            id: value.guid.isEmpty
                ? (value.infoHash.isEmpty ? value.link : value.infoHash)
                : value.guid,
            title: value.title.isEmpty ? "Torrent" : value.title,
            summary: value.summary,
            tracker: value.tracker,
            downloadURL: downloadURL,
            magnetURL: magnetURL,
            posterURL: URL(string: value.poster),
            detailsURL: URL(string: value.details),
            size: value.size,
            seeders: value.seeders,
            peers: value.peers,
            categories: Array(Set(value.categories)),
            publishedAt: value.publishedAt,
            infoHash: value.infoHash,
            year: value.year
        )
    }

    private static func parseDate(_ value: String) -> Date? {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "EEE, dd MMM yyyy HH:mm:ss Z"
        return formatter.date(from: value)
    }

    private static func plainText(_ value: String) -> String {
        let withoutTags = value.replacingOccurrences(
            of: #"<[^>]+>"#,
            with: " ",
            options: .regularExpression
        )
        return withoutTags
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(
                of: #"\s+"#,
                with: " ",
                options: .regularExpression
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
