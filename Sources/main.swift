import AppKit
import CoreImage
import CoreImage.CIFilterBuiltins
import Darwin
import QuartzCore
import SwiftUI
import UserNotifications

private let webUIURL = URL(string: "http://localhost:8090")!
private let savedPathKey = "TorrServerExecutablePath"
private let autoStartServerKey = "AutoStartServerOnLaunch"
private let showSpeedInMenuBarKey = "ShowSpeedInMenuBar"
private let hideDockIconKey = "HideDockIcon"
private let languageKey = "AppLanguage"
private let notificationsEnabledKey = "NotificationsEnabled"
private let speedDisplayUnitKey = "SpeedDisplayUnit"
private let iinaDownloadURL = URL(string: "https://iina.io/download/")!
private let vlcDownloadURL = URL(
    string: "https://www.videolan.org/vlc/download-macosx.html"
)!

struct AppError: LocalizedError {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var errorDescription: String? { message }
}

enum AppLanguage: String {
    case russian = "ru"
    case english = "en"

    static var systemDefault: AppLanguage {
        Locale.current.languageCode == "ru" ? .russian : .english
    }
}

enum SpeedDisplayUnit: String, CaseIterable {
    case automatic
    case megabytes
    case megabits
}

struct Texts {
    let language: AppLanguage

    var about: String { language == .russian ? "О TorrServer" : "About TorrServer" }
    var quit: String { language == .russian ? "Завершить приложение" : "Quit" }
    var edit: String { language == .russian ? "Правка" : "Edit" }
    var undo: String { language == .russian ? "Отменить" : "Undo" }
    var redo: String { language == .russian ? "Повторить" : "Redo" }
    var cut: String { language == .russian ? "Вырезать" : "Cut" }
    var copy: String { language == .russian ? "Копировать" : "Copy" }
    var paste: String { language == .russian ? "Вставить" : "Paste" }
    var selectAll: String { language == .russian ? "Выбрать всё" : "Select All" }
    var title: String { "TorrServer" }
    var choose: String { language == .russian ? "Выбрать" : "Choose" }
    var downloadArm: String { language == .russian ? "Скачать ARM" : "Download ARM" }
    var start: String { language == .russian ? "Запустить" : "Start" }
    var stop: String { language == .russian ? "Остановить" : "Stop" }
    var webUI: String { language == .russian ? "Web UI" : "Web UI" }
    var openWebUI: String { language == .russian ? "Открыть Web UI" : "Open Web UI" }
    var showWindow: String { language == .russian ? "Показать окно" : "Show Window" }
    var downloadMenu: String {
        language == .russian
            ? "Скачать TorrServer для Apple Silicon"
            : "Download TorrServer for Apple Silicon"
    }
    var launchAtLogin: String {
        language == .russian ? "Открывать при входе в macOS" : "Open at Login"
    }
    var autoStartServer: String {
        language == .russian
            ? "Запускать сервер при открытии приложения"
            : "Start server when app opens"
    }
    var showSpeed: String {
        language == .russian
            ? "Показывать скорость в меню баре"
            : "Show speed in menu bar"
    }
    var notifications: String {
        language == .russian ? "Системные уведомления" : "System notifications"
    }
    var speedFormat: String {
        language == .russian ? "Формат скорости" : "Speed format"
    }
    var automaticSpeed: String { language == .russian ? "Авто" : "Auto" }
    var megabytesSpeed: String { "MB/s" }
    var megabitsSpeed: String { "Mbit/s" }
    var hideDockIcon: String {
        language == .russian
            ? "Показывать приложение только в меню баре"
            : "Show app in menu bar only"
    }
    var playerHelpTitle: String {
        language == .russian ? "Плееры для просмотра" : "Playback apps"
    }
    var playerHelpMessage: String {
        language == .russian
            ? "Приложение автоматически проверяет IINA, VLC и Infuse. Нажмите установленный плеер, чтобы выбрать его."
            : "The app automatically checks IINA, VLC, and Infuse. Select any installed player to make it the default."
    }
    var languageLabel: String { language == .russian ? "Язык" : "Language" }
    var russian: String { "Russian" }
    var english: String { "English" }
    var stopped: String { language == .russian ? "Остановлен" : "Stopped" }
    var chooseOrDownload: String {
        language == .russian ? "Выберите или скачайте TorrServer" : "Choose or download TorrServer"
    }
    var torrServerNotSelected: String {
        language == .russian ? "TorrServer не выбран" : "TorrServer is not selected"
    }
    func running(pid: Int32) -> String {
        language == .russian ? "Работает · PID \(pid)" : "Running · PID \(pid)"
    }
    var stopping: String { language == .russian ? "Останавливается…" : "Stopping…" }
    var downloading: String {
        language == .russian ? "Скачивается TorrServer…" : "Downloading TorrServer…"
    }
    var launchError: String { language == .russian ? "Ошибка запуска" : "Launch Error" }
    func error(_ message: String) -> String {
        language == .russian ? "Ошибка: \(message)" : "Error: \(message)"
    }
    func errorTooltip(_ message: String) -> String {
        if language == .russian {
            return """
            TorrServer неожиданно завершил работу.

            \(message)

            Возможные причины: порт 8090 уже занят другой копией TorrServer, \
            исполняемый файл повреждён или macOS запретила его запуск.
            """
        }

        return """
        TorrServer stopped unexpectedly.

        \(message)

        Possible causes: port 8090 is already used by another TorrServer process, \
        the executable is damaged, or macOS blocked it from launching.
        """
    }
    var speedLabel: String { language == .russian ? "Скорость" : "Speed" }
    var speedOff: String { language == .russian ? "выключена" : "off" }
    var speedNoData: String { language == .russian ? "нет данных" : "no data" }
    var materialsTitle: String { language == .russian ? "Материалы" : "Materials" }
    var currentMaterial: String {
        language == .russian ? "Сейчас транслируется" : "Now streaming"
    }
    var recentMaterial: String {
        language == .russian ? "Последний материал" : "Latest material"
    }
    var noActiveMaterial: String {
        language == .russian ? "Нет активной трансляции" : "No active stream"
    }
    var buffer: String { language == .russian ? "Буфер" : "Buffer" }
    var seeds: String { language == .russian ? "Сиды" : "Seeds" }
    var peers: String { language == .russian ? "Пиры" : "Peers" }
    var speedHistory: String {
        language == .russian ? "Скорость за 60 секунд" : "Speed over 60 seconds"
    }
    var localWebUI: String {
        language == .russian ? "Web UI в локальной сети" : "Web UI on local network"
    }
    var showQRCode: String {
        language == .russian ? "Показать QR-код" : "Show QR code"
    }
    var hideQRCode: String {
        language == .russian ? "Скрыть QR-код" : "Hide QR code"
    }
    var openWindow: String {
        language == .russian ? "Открыть приложение" : "Open app"
    }
    var serverStartedNotificationTitle: String {
        language == .russian ? "TorrServer запущен" : "TorrServer started"
    }
    var serverStartedNotificationMessage: String {
        language == .russian
            ? "Сервер готов к работе на порту 8090."
            : "The server is ready on port 8090."
    }
    var updateInstalledNotificationTitle: String {
        language == .russian ? "Обновление установлено" : "Update installed"
    }
    var errorNotificationTitle: String {
        language == .russian ? "Ошибка TorrServer" : "TorrServer error"
    }
    var notificationPermissionDeniedTitle: String {
        language == .russian ? "Уведомления недоступны" : "Notifications unavailable"
    }
    var notificationPermissionDeniedMessage: String {
        language == .russian
            ? "Разрешите уведомления для TorrServer в Системных настройках macOS."
            : "Allow TorrServer notifications in macOS System Settings."
    }
    var loadingMaterials: String { language == .russian ? "Загрузка…" : "Loading…" }
    var noMaterials: String { language == .russian ? "Нет материалов" : "No materials" }
    func moreMaterials(_ count: Int) -> String {
        language == .russian ? "Еще \(count)…" : "\(count) more…"
    }
    var seedsShort: String { "S" }
    var peersShort: String { "P" }
    var choosePanelTitle: String {
        language == .russian
            ? "Выберите исполняемый файл TorrServer"
            : "Choose TorrServer executable"
    }
    var choosePanelMessage: String {
        language == .russian
            ? "Обычно файл называется TorrServer или TorrServer-darwin-arm64."
            : "The file is usually named TorrServer or TorrServer-darwin-arm64."
    }
    var choosePanelPrompt: String { language == .russian ? "Выбрать" : "Choose" }
    var chooseTorrServerAlertTitle: String {
        language == .russian ? "Выберите TorrServer" : "Choose TorrServer"
    }
    var chooseTorrServerAlertMessage: String {
        language == .russian
            ? "Сначала выберите файл вручную или скачайте последнюю версию для Apple Silicon."
            : "Choose the executable manually or download the latest Apple Silicon version first."
    }
    var startFailedTitle: String {
        language == .russian ? "TorrServer не запущен" : "TorrServer did not start"
    }
    var downloadDoneTitle: String {
        language == .russian ? "TorrServer скачан" : "TorrServer downloaded"
    }
    var downloadDoneMessage: String {
        language == .russian
            ? "Файл сохранен и выбран автоматически."
            : "The file was saved and selected automatically."
    }
    var downloadFailedTitle: String {
        language == .russian ? "Не удалось скачать TorrServer" : "Could not download TorrServer"
    }
    var launchAtLoginFailedTitle: String {
        language == .russian ? "Автозапуск не изменен" : "Open at Login was not changed"
    }
    var aboutCredits: String {
        "Created for Holy Mayhem\nNative macOS GUI for TorrServer"
    }
}

final class TorrServerProcessController {
    enum State {
        case stopped
        case running(pid: Int32)
        case stopping
        case failed(String)
    }

    var onStateChange: ((State) -> Void)?

    private(set) var state: State = .stopped {
        didSet { onStateChange?(state) }
    }

    private var task: Process?
    private var stopCompletions: [() -> Void] = []
    private var forceStopWorkItem: DispatchWorkItem?

    var isRunning: Bool {
        task?.isRunning == true
    }

    func start(executablePath: String) throws {
        guard !isRunning else { return }

        let expandedPath = NSString(string: executablePath)
            .expandingTildeInPath
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let executableURL = URL(fileURLWithPath: expandedPath).standardizedFileURL

        var isDirectory: ObjCBool = false
        guard FileManager.default.fileExists(
            atPath: executableURL.path,
            isDirectory: &isDirectory
        ), !isDirectory.boolValue else {
            throw AppError("Файл TorrServer не найден. Выберите его заново.")
        }

        try makeExecutableIfNeeded(at: executableURL)

        let newTask = Process()
        newTask.executableURL = executableURL
        newTask.currentDirectoryURL = executableURL.deletingLastPathComponent()
        newTask.standardOutput = FileHandle.nullDevice
        newTask.standardError = FileHandle.nullDevice
        newTask.terminationHandler = { [weak self] finishedTask in
            DispatchQueue.main.async {
                self?.handleTermination(finishedTask)
            }
        }

        do {
            try newTask.run()
            task = newTask
            state = .running(pid: newTask.processIdentifier)
        } catch {
            task = nil
            state = .failed(error.localizedDescription)
            throw AppError("Не удалось запустить TorrServer: \(error.localizedDescription)")
        }
    }

    func stop(completion: (() -> Void)? = nil) {
        if let completion {
            stopCompletions.append(completion)
        }

        guard let runningTask = task, runningTask.isRunning else {
            finishStopCompletions()
            if case .failed = state { return }
            state = .stopped
            return
        }

        state = .stopping
        runningTask.terminate()

        let pid = runningTask.processIdentifier
        let workItem = DispatchWorkItem { [weak self, weak runningTask] in
            guard let runningTask, runningTask.isRunning else { return }
            Darwin.kill(pid, SIGKILL)
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                guard let self, self.task === runningTask else { return }
                self.task = nil
                self.state = .stopped
                self.finishStopCompletions()
            }
        }
        forceStopWorkItem?.cancel()
        forceStopWorkItem = workItem
        DispatchQueue.global(qos: .utility)
            .asyncAfter(deadline: .now() + 3, execute: workItem)
    }

    private func handleTermination(_ finishedTask: Process) {
        guard task === finishedTask else { return }

        forceStopWorkItem?.cancel()
        forceStopWorkItem = nil
        task = nil

        let wasStopping: Bool
        if case .stopping = state {
            wasStopping = true
        } else {
            wasStopping = false
        }

        if wasStopping || finishedTask.terminationStatus == 0 {
            state = .stopped
        } else {
            state = .failed("Процесс завершился с кодом \(finishedTask.terminationStatus)")
        }
        finishStopCompletions()
    }

    private func finishStopCompletions() {
        let completions = stopCompletions
        stopCompletions.removeAll()
        completions.forEach { $0() }
    }

    private func makeExecutableIfNeeded(at url: URL) throws {
        if FileManager.default.isExecutableFile(atPath: url.path) {
            return
        }

        let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
        let currentMode = (attributes[.posixPermissions] as? NSNumber)?.uint16Value ?? 0o644
        let executableMode = currentMode | 0o111
        try FileManager.default.setAttributes(
            [.posixPermissions: NSNumber(value: executableMode)],
            ofItemAtPath: url.path
        )

        guard FileManager.default.isExecutableFile(atPath: url.path) else {
            throw AppError("macOS не разрешила сделать выбранный файл исполняемым.")
        }
    }
}

final class TorrServerDownloader {
    private let latestReleaseURL = URL(
        string: "https://api.github.com/repos/YouROK/TorrServer/releases/latest"
    )!
    private let assetName = "TorrServer-darwin-arm64"

    func downloadLatestDarwinArm64(completion: @escaping (Result<URL, Error>) -> Void) {
        URLSession.shared.dataTask(with: latestReleaseURL) { [assetName] data, _, error in
            if let error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }

            do {
                guard let data else {
                    throw AppError("GitHub не вернул данные релиза.")
                }

                let assetURL = try self.findAssetURL(named: assetName, in: data)
                self.downloadAsset(from: assetURL, completion: completion)
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }.resume()
    }

    private func findAssetURL(named assetName: String, in data: Data) throws -> URL {
        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let assets = json["assets"] as? [[String: Any]]
        else {
            throw AppError("Не удалось прочитать список файлов последнего релиза.")
        }

        guard
            let asset = assets.first(where: { $0["name"] as? String == assetName }),
            let downloadString = asset["browser_download_url"] as? String,
            let downloadURL = URL(string: downloadString)
        else {
            throw AppError("В последнем релизе не найден файл \(assetName).")
        }

        return downloadURL
    }

    private func downloadAsset(
        from url: URL,
        completion: @escaping (Result<URL, Error>) -> Void
    ) {
        URLSession.shared.downloadTask(with: url) { temporaryURL, _, error in
            if let error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }

            do {
                guard let temporaryURL else {
                    throw AppError("Загрузка завершилась без файла.")
                }

                let destination = try self.downloadDestinationURL()
                let directory = destination.deletingLastPathComponent()
                try FileManager.default.createDirectory(
                    at: directory,
                    withIntermediateDirectories: true
                )

                if FileManager.default.fileExists(atPath: destination.path) {
                    try FileManager.default.removeItem(at: destination)
                }

                try FileManager.default.moveItem(at: temporaryURL, to: destination)
                try FileManager.default.setAttributes(
                    [.posixPermissions: NSNumber(value: 0o755)],
                    ofItemAtPath: destination.path
                )

                DispatchQueue.main.async { completion(.success(destination)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }.resume()
    }

    private func downloadDestinationURL() throws -> URL {
        guard let appSupportURL = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first else {
            throw AppError("Не удалось найти папку Application Support.")
        }

        return appSupportURL
            .appendingPathComponent("TorrServer Manager", isDirectory: true)
            .appendingPathComponent(assetName)
    }
}

final class LaunchAtLoginController {
    private let label = "local.codex.torrserver-manager.login"

    var isEnabled: Bool {
        FileManager.default.fileExists(atPath: plistURL.path)
    }

    func setEnabled(_ enabled: Bool) throws {
        if enabled {
            try installLaunchAgent()
        } else if FileManager.default.fileExists(atPath: plistURL.path) {
            try FileManager.default.removeItem(at: plistURL)
        }
    }

    private var plistURL: URL {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library", isDirectory: true)
            .appendingPathComponent("LaunchAgents", isDirectory: true)
            .appendingPathComponent("\(label).plist")
    }

    private func installLaunchAgent() throws {
        let appPath = Bundle.main.bundlePath
        guard appPath.hasSuffix(".app") else {
            throw AppError("Автозапуск работает только у собранного .app приложения.")
        }

        let plist: [String: Any] = [
            "Label": label,
            "ProgramArguments": ["/usr/bin/open", appPath],
            "RunAtLoad": true
        ]
        let data = try PropertyListSerialization.data(
            fromPropertyList: plist,
            format: .xml,
            options: 0
        )
        try FileManager.default.createDirectory(
            at: plistURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try data.write(to: plistURL, options: .atomic)
    }
}

final class TorrServerSpeedMonitor {
    var onSpeedChange: ((Double?) -> Void)?

    private let statURL = URL(string: "http://127.0.0.1:8090/stat")!
    private var timer: Timer?
    private var previousSample: (bytes: Int64, date: Date)?
    private var isRequestInFlight = false

    func start() {
        guard timer == nil else { return }

        previousSample = nil
        fetchStat()
        timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
            self?.fetchStat()
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        previousSample = nil
        isRequestInFlight = false
        onSpeedChange?(nil)
    }

    private func fetchStat() {
        guard !isRequestInFlight else { return }
        isRequestInFlight = true

        var request = URLRequest(url: statURL)
        request.timeoutInterval = 1.5

        URLSession.shared.dataTask(with: request) { [weak self] data, _, _ in
            guard let self else { return }

            let now = Date()
            let bytes = data
                .flatMap { String(data: $0, encoding: .utf8) }
                .flatMap(Self.extractReadDataBytes)

            DispatchQueue.main.async {
                self.isRequestInFlight = false

                guard let bytes else {
                    self.previousSample = nil
                    self.onSpeedChange?(nil)
                    return
                }

                let speed: Double
                if let previous = self.previousSample {
                    let interval = max(now.timeIntervalSince(previous.date), 0.1)
                    speed = max(0, Double(bytes - previous.bytes) / interval)
                } else {
                    speed = 0
                }

                self.previousSample = (bytes, now)
                self.onSpeedChange?(speed)
            }
        }.resume()
    }

    private static func extractReadDataBytes(from text: String) -> Int64? {
        extractCounter(named: "BytesReadData", from: text)
            ?? extractCounter(named: "BytesReadUsefulData", from: text)
            ?? extractCounter(named: "BytesRead", from: text)
    }

    private static func extractCounter(named name: String, from text: String) -> Int64? {
        let pattern = "\(name):\\s*\\([^)]*\\)\\s*(\\d+)"

        guard
            let regex = try? NSRegularExpression(pattern: pattern),
            let match = regex.firstMatch(
                in: text,
                range: NSRange(text.startIndex..<text.endIndex, in: text)
            ),
            let range = Range(match.range(at: 1), in: text)
        else {
            return nil
        }

        return Int64(text[range])
    }
}

struct TorrentSummary {
    let title: String
    let size: Int64
    let loadedSize: Int64?
    let seeders: Int
    let activePeers: Int
    let totalPeers: Int
    let status: Int
    let timestamp: Int64
    let downloadSpeed: Double
    let uploadSpeed: Double

    var isActive: Bool {
        downloadSpeed > 0
            || uploadSpeed > 0
            || activePeers > 0
            || (1...3).contains(status)
    }

    var bufferProgress: Double? {
        guard size > 0, let loadedSize else { return nil }
        return min(max(Double(loadedSize) / Double(size), 0), 1)
    }
}

final class TorrServerLibraryClient {
    private let torrentsURL = URL(string: "http://127.0.0.1:8090/torrents")!

    func fetchTorrents(completion: @escaping (Result<[TorrentSummary], Error>) -> Void) {
        var request = URLRequest(url: torrentsURL)
        request.httpMethod = "POST"
        request.timeoutInterval = 1.5
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = #"{"action":"list"}"#.data(using: .utf8)

        URLSession.shared.dataTask(with: request) { data, _, error in
            if let error {
                DispatchQueue.main.async { completion(.failure(error)) }
                return
            }

            do {
                guard let data else {
                    throw AppError("TorrServer returned no data.")
                }

                let raw = try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []
                let torrents = raw.map(Self.parseTorrent).sorted { left, right in
                    if left.isActive != right.isActive {
                        return left.isActive
                    }
                    return left.timestamp > right.timestamp
                }
                DispatchQueue.main.async { completion(.success(torrents)) }
            } catch {
                DispatchQueue.main.async { completion(.failure(error)) }
            }
        }.resume()
    }

    private static func parseTorrent(_ dictionary: [String: Any]) -> TorrentSummary {
        let title = stringValue(dictionary["title"])
            ?? stringValue(dictionary["name"])
            ?? stringValue(dictionary["hash"])
            ?? "Torrent"
        let loadedSize = int64Value(value(in: dictionary, keys: [
            "loaded_size", "LoadedSize"
        ]))
        let size = int64Value(value(in: dictionary, keys: [
            "torrent_size", "TorrentSize"
        ]))
            ?? loadedSize
            ?? 0

        return TorrentSummary(
            title: title,
            size: size,
            loadedSize: loadedSize,
            seeders: intValue(value(in: dictionary, keys: [
                "connected_seeders", "ConnectedSeeders"
            ])),
            activePeers: intValue(value(in: dictionary, keys: [
                "active_peers", "ActivePeers"
            ])),
            totalPeers: intValue(value(in: dictionary, keys: [
                "total_peers", "TotalPeers"
            ])),
            status: intValue(value(in: dictionary, keys: [
                "stat", "Stat"
            ])),
            timestamp: int64Value(value(in: dictionary, keys: [
                "timestamp", "Timestamp"
            ])) ?? 0,
            downloadSpeed: doubleValue(value(in: dictionary, keys: [
                "download_speed", "DownloadSpeed"
            ])),
            uploadSpeed: doubleValue(value(in: dictionary, keys: [
                "upload_speed", "UploadSpeed"
            ]))
        )
    }

    private static func value(in dictionary: [String: Any], keys: [String]) -> Any? {
        for key in keys {
            if let value = dictionary[key] {
                return value
            }
        }
        return nil
    }

    private static func stringValue(_ value: Any?) -> String? {
        (value as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func intValue(_ value: Any?) -> Int {
        if let value = value as? Int { return value }
        if let value = value as? NSNumber { return value.intValue }
        return 0
    }

    private static func int64Value(_ value: Any?) -> Int64? {
        if let value = value as? Int64 { return value }
        if let value = value as? Int { return Int64(value) }
        if let value = value as? NSNumber { return value.int64Value }
        return nil
    }

    private static func doubleValue(_ value: Any?) -> Double {
        if let value = value as? Double { return value }
        if let value = value as? NSNumber { return value.doubleValue }
        return 0
    }
}

enum SpeedFormatter {
    static func string(
        bytesPerSecond: Double,
        unit: SpeedDisplayUnit
    ) -> String {
        let safeValue = max(bytesPerSecond, 0)

        switch unit {
        case .automatic:
            if safeValue >= 1024 * 1024 {
                return String(format: "%.1f MB/s", safeValue / 1024 / 1024)
            }
            return String(format: "%.0f KB/s", safeValue / 1024)

        case .megabytes:
            return String(format: "%.2f MB/s", safeValue / 1024 / 1024)

        case .megabits:
            return String(format: "%.1f Mbit/s", safeValue * 8 / 1_000_000)
        }
    }
}

enum QRCodeGenerator {
    static func image(for string: String, size: CGFloat = 180) -> NSImage? {
        let filter = CIFilter.qrCodeGenerator()
        filter.message = Data(string.utf8)
        filter.correctionLevel = "M"

        guard let outputImage = filter.outputImage else { return nil }
        let scale = max(size / outputImage.extent.width, 1)
        let scaled = outputImage.transformed(
            by: CGAffineTransform(scaleX: scale, y: scale)
        )
        let context = CIContext(options: [.useSoftwareRenderer: false])

        guard let cgImage = context.createCGImage(scaled, from: scaled.extent) else {
            return nil
        }

        return NSImage(
            cgImage: cgImage,
            size: NSSize(width: size, height: size)
        )
    }
}

enum LocalWebUIAddress {
    static func url() -> URL {
        let address = preferredIPv4Address() ?? "localhost"
        return URL(string: "http://\(address):8090") ?? webUIURL
    }

    private static func preferredIPv4Address() -> String? {
        var interfaces: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfaces) == 0, let first = interfaces else {
            return nil
        }
        defer { freeifaddrs(interfaces) }

        var candidates: [(priority: Int, address: String)] = []
        var pointer: UnsafeMutablePointer<ifaddrs>? = first

        while let current = pointer {
            defer { pointer = current.pointee.ifa_next }

            guard
                let addressPointer = current.pointee.ifa_addr,
                addressPointer.pointee.sa_family == UInt8(AF_INET)
            else {
                continue
            }

            let interfaceName = String(cString: current.pointee.ifa_name)
            guard interfaceName != "lo0" else { continue }

            var socketAddress = UnsafeRawPointer(addressPointer)
                .assumingMemoryBound(to: sockaddr_in.self)
                .pointee
            var buffer = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))

            guard inet_ntop(
                AF_INET,
                &socketAddress.sin_addr,
                &buffer,
                socklen_t(INET_ADDRSTRLEN)
            ) != nil else {
                continue
            }

            let address = String(cString: buffer)
            guard !address.hasPrefix("169.254.") else { continue }

            let priority: Int
            switch interfaceName {
            case "en0": priority = 0
            case "en1": priority = 1
            default: priority = 2
            }
            candidates.append((priority, address))
        }

        return candidates.sorted { $0.priority < $1.priority }.first?.address
    }
}

final class NotificationController: NSObject, UNUserNotificationCenterDelegate {
    private let center = UNUserNotificationCenter.current()

    override init() {
        super.init()
        center.delegate = self
    }

    func setEnabled(_ enabled: Bool, completion: @escaping (Bool) -> Void) {
        guard enabled else {
            UserDefaults.standard.set(false, forKey: notificationsEnabledKey)
            completion(false)
            return
        }

        center.requestAuthorization(options: [.alert, .sound]) { granted, _ in
            DispatchQueue.main.async {
                UserDefaults.standard.set(granted, forKey: notificationsEnabledKey)
                completion(granted)
            }
        }
    }

    func send(title: String, body: String) {
        guard UserDefaults.standard.bool(forKey: notificationsEnabledKey) else {
            return
        }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        center.add(
            UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil
            )
        )
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        completionHandler([.banner, .sound])
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, NSPopoverDelegate {
    private enum MenuBarVisualState {
        case stopped
        case running
        case streaming
        case buffering
        case failed
        case updating
    }
    private let processController = TorrServerProcessController()
    private let downloader = TorrServerDownloader()
    private let launchAtLoginController = LaunchAtLoginController()
    private let speedMonitor = TorrServerSpeedMonitor()
    private let libraryClient = TorrServerLibraryClient()
    private let notificationController = NotificationController()
    private let diagnosticsService = TorrServerDiagnosticsService()
    private let mainWindowModel = MainWindowModel()
    private let libraryModel = LibraryViewModel()
    private let searchModel = SearchViewModel()
    private let popoverModel = MenuBarPopoverModel()

    private var window: NSWindow!
    private var serverContentSize = NSSize(width: 580, height: 500)

    private var statusItem: NSStatusItem!
    private var statusPopover: NSPopover!
    private var popoverRefreshTimer: Timer?
    private var menuBarMaterialTimer: Timer?
    private var menuBarAnimationTimer: Timer?
    private var localPopoverEventMonitor: Any?
    private var globalPopoverEventMonitor: Any?

    private var isDownloading = false
    private var hasRepliedToTermination = false
    private var currentSpeedBytesPerSecond: Double?
    private var currentStatusIconColor: NSColor = .systemGray
    private var currentTorrents: [TorrentSummary] = []
    private var speedHistory: [Double] = []
    private var hasAnnouncedRunningState = false
    private var menuBarAnimationPhase: CGFloat = 0

    func applicationDidFinishLaunching(_ notification: Notification) {
        registerDefaultSettings()
        applyActivationPolicy()
        buildMainMenu()
        buildStatusItem()
        buildWindow()
        applyLanguage()

        processController.onStateChange = { [weak self] state in
            self?.handleNotification(for: state)
            self?.updateUI(for: state)
        }
        speedMonitor.onSpeedChange = { [weak self] speed in
            self?.recordSpeedSample(speed)
        }
        updateUI(for: .stopped)
        refreshPlayerAvailability()
        refreshStorage()

        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        if UserDefaults.standard.bool(forKey: autoStartServerKey), hasExecutablePath {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                self.startServer(nil)
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        guard processController.isRunning else {
            return .terminateNow
        }

        guard !hasRepliedToTermination else {
            return .terminateLater
        }

        processController.stop { [weak self, weak sender] in
            guard let self, !self.hasRepliedToTermination else { return }
            self.hasRepliedToTermination = true
            sender?.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }

    @objc private func chooseExecutable(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.title = texts.choosePanelTitle
        panel.message = texts.choosePanelMessage
        panel.prompt = texts.choosePanelPrompt
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.treatsFilePackagesAsDirectories = false

        if panel.runModal() == .OK, let url = panel.url {
            mainWindowModel.path = url.path
            saveCurrentPath()
            updateUI(for: processController.state)
        }
    }

    @objc private func downloadLatestTorrServer(_ sender: Any?) {
        guard !isDownloading else { return }

        isDownloading = true
        updateUI(for: processController.state)

        downloader.downloadLatestDarwinArm64 { [weak self] result in
            guard let self else { return }
            self.isDownloading = false

            switch result {
            case .success(let url):
                self.mainWindowModel.path = url.path
                self.saveCurrentPath()
                self.updateUI(for: self.processController.state)
                self.showAlert(
                    title: self.texts.downloadDoneTitle,
                    message: self.texts.downloadDoneMessage
                )
                self.notificationController.send(
                    title: self.texts.updateInstalledNotificationTitle,
                    body: self.texts.downloadDoneMessage
                )
            case .failure(let error):
                self.updateUI(for: self.processController.state)
                self.showAlert(
                    title: self.texts.downloadFailedTitle,
                    message: error.localizedDescription
                )
                self.notificationController.send(
                    title: self.texts.errorNotificationTitle,
                    body: error.localizedDescription
                )
            }
        }
    }

    @objc private func startServer(_ sender: Any?) {
        saveCurrentPath()

        guard hasExecutablePath else {
            showAlert(
                title: texts.chooseTorrServerAlertTitle,
                message: texts.chooseTorrServerAlertMessage
            )
            return
        }

        do {
            try processController.start(executablePath: executablePath)
        } catch {
            showAlert(
                title: texts.startFailedTitle,
                message: error.localizedDescription
            )
        }
    }

    @objc private func stopServer(_ sender: Any?) {
        processController.stop()
    }

    @objc private func openWebUI(_ sender: Any?) {
        NSWorkspace.shared.open(webUIURL)
    }

    @objc private func showMainWindow(_ sender: Any?) {
        if window == nil {
            buildWindow()
        }
        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            try launchAtLoginController.setEnabled(enabled)
        } catch {
            showAlert(
                title: texts.launchAtLoginFailedTitle,
                message: error.localizedDescription
            )
        }
        updateUI(for: processController.state)
    }

    private func setAutoStartServer(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: autoStartServerKey)
        updateUI(for: processController.state)
    }

    private func setSpeedInMenuBar(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: showSpeedInMenuBarKey)
        updateUI(for: processController.state)
    }

    private func setHideDockIcon(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: hideDockIconKey)
        applyActivationPolicy(keepingWindowVisible: true)
        updateUI(for: processController.state)
    }

    private func setLanguage(_ language: AppLanguage) {
        currentLanguage = language
        applyLanguage()
        updateUI(for: processController.state)
        updatePopoverMaterial(with: currentTorrents)
    }

    private func setNotificationsEnabled(_ enabled: Bool) {
        notificationController.setEnabled(enabled) { [weak self] granted in
            guard let self else { return }
            self.mainWindowModel.notificationsEnabled = granted

            if enabled && !granted {
                self.showAlert(
                    title: self.texts.notificationPermissionDeniedTitle,
                    message: self.texts.notificationPermissionDeniedMessage
                )
            }
        }
    }

    private func setSpeedDisplayUnit(_ unit: SpeedDisplayUnit) {
        UserDefaults.standard.set(unit.rawValue, forKey: speedDisplayUnitKey)
        mainWindowModel.speedUnit = unit
        refreshSpeedDisplay()
    }

    @objc private func showAboutPanel(_ sender: Any?) {
        let version = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "2.4.1"
        let build = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleVersion"
        ) as? String ?? "24"
        let credits = NSAttributedString(
            string: texts.aboutCredits,
            attributes: [
                .font: NSFont.systemFont(ofSize: 12),
                .foregroundColor: NSColor.secondaryLabelColor
            ]
        )

        NSApp.orderFrontStandardAboutPanel(options: [
            .applicationName: "TorrServer",
            .applicationVersion: "\(version) (\(build))",
            .credits: credits
        ])
    }

    private var executablePath: String {
        mainWindowModel.path.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasExecutablePath: Bool {
        !executablePath.isEmpty
    }

    private var isSpeedDisplayEnabled: Bool {
        UserDefaults.standard.bool(forKey: showSpeedInMenuBarKey)
    }

    private var currentSpeedDisplayUnit: SpeedDisplayUnit {
        guard
            let rawValue = UserDefaults.standard.string(forKey: speedDisplayUnitKey),
            let unit = SpeedDisplayUnit(rawValue: rawValue)
        else {
            return .automatic
        }
        return unit
    }

    private var currentLanguage: AppLanguage {
        get {
            if let rawValue = UserDefaults.standard.string(forKey: languageKey),
               let language = AppLanguage(rawValue: rawValue) {
                return language
            }
            return .systemDefault
        }
        set {
            UserDefaults.standard.set(newValue.rawValue, forKey: languageKey)
        }
    }

    private var texts: Texts {
        Texts(language: currentLanguage)
    }

    private func registerDefaultSettings() {
        UserDefaults.standard.register(defaults: [
            showSpeedInMenuBarKey: true,
            hideDockIconKey: false,
            notificationsEnabledKey: false,
            speedDisplayUnitKey: SpeedDisplayUnit.automatic.rawValue
        ])
    }

    private func applyActivationPolicy(keepingWindowVisible: Bool = false) {
        let shouldHideDockIcon = UserDefaults.standard.bool(forKey: hideDockIconKey)
        let shouldRestoreWindow = keepingWindowVisible && window?.isVisible == true
        NSApp.setActivationPolicy(shouldHideDockIcon ? .accessory : .regular)

        guard shouldRestoreWindow else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self, self.window != nil else { return }
            NSApp.activate(ignoringOtherApps: true)
            self.window.orderFrontRegardless()
            self.window.makeKey()
        }
    }

    private func buildWindow() {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 580, height: 500),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        window.title = "TorrServer"
        window.isReleasedWhenClosed = false
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.titlebarSeparatorStyle = .none
        window.isMovableByWindowBackground = true
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        window.standardWindowButton(.zoomButton)?.isEnabled = false

        mainWindowModel.path = UserDefaults.standard.string(forKey: savedPathKey) ?? ""
        mainWindowModel.language = currentLanguage
        mainWindowModel.onPathChanged = { [weak self] _ in
            guard let self else { return }
            self.saveCurrentPath()
            self.updateUI(for: self.processController.state)
        }
        mainWindowModel.onChoose = { [weak self] in self?.chooseExecutable(nil) }
        mainWindowModel.onDownload = { [weak self] in self?.downloadLatestTorrServer(nil) }
        mainWindowModel.onStart = { [weak self] in self?.startServer(nil) }
        mainWindowModel.onStop = { [weak self] in self?.stopServer(nil) }
        mainWindowModel.onOpenWeb = { [weak self] in self?.openWebUI(nil) }
        mainWindowModel.onLaunchAtLoginChanged = { [weak self] enabled in
            self?.setLaunchAtLogin(enabled)
        }
        mainWindowModel.onAutoStartChanged = { [weak self] enabled in
            self?.setAutoStartServer(enabled)
        }
        mainWindowModel.onShowSpeedChanged = { [weak self] enabled in
            self?.setSpeedInMenuBar(enabled)
        }
        mainWindowModel.onHideDockIconChanged = { [weak self] enabled in
            self?.setHideDockIcon(enabled)
        }
        mainWindowModel.onNotificationsChanged = { [weak self] enabled in
            self?.setNotificationsEnabled(enabled)
        }
        mainWindowModel.onSpeedUnitChanged = { [weak self] unit in
            self?.setSpeedDisplayUnit(unit)
        }
        mainWindowModel.onLanguageChanged = { [weak self] language in
            self?.setLanguage(language)
        }
        mainWindowModel.onSectionChanged = { [weak self] section in
            self?.resizeWindow(for: section)
        }
        mainWindowModel.onOpenIINADownload = {
            NSWorkspace.shared.open(iinaDownloadURL)
        }
        mainWindowModel.onOpenVLCDownload = {
            NSWorkspace.shared.open(vlcDownloadURL)
        }
        mainWindowModel.onOpenInfuseDownload = {
            guard let url = ExternalPlayerChoice.infuse.downloadURL else { return }
            NSWorkspace.shared.open(url)
        }
        mainWindowModel.onSelectPlayer = { [weak self] choice in
            guard let self else { return }
            self.libraryModel.setPlayer(choice, language: self.currentLanguage)
            self.refreshPlayerAvailability()
        }
        libraryModel.onPlayerChanged = { [weak self] _ in
            self?.refreshPlayerAvailability()
        }
        mainWindowModel.onRefreshStorage = { [weak self] in
            self?.refreshStorage()
        }
        mainWindowModel.onClearCache = { [weak self] in
            self?.clearTorrServerCache()
        }
        mainWindowModel.onCheckPort = { [weak self] in
            self?.checkTorrServerPort()
        }
        mainWindowModel.onFindTorrServer = { [weak self] in
            self?.findOtherTorrServerProcesses()
        }
        mainWindowModel.onCheckExecutable = { [weak self] in
            self?.checkTorrServerExecutable()
        }
        mainWindowModel.onCopyDiagnosticReport = { [weak self] in
            self?.copyDiagnosticReport()
        }
        searchModel.onTorrentAdded = { [weak self] hash in
            self?.libraryModel.refresh(selectingHash: hash)
        }

        let hostingView = NSHostingView(
            rootView: ApplicationRootView(
                mainModel: mainWindowModel,
                libraryModel: libraryModel,
                searchModel: searchModel
            )
        )
        window.contentView = hostingView
        hostingView.layoutSubtreeIfNeeded()

        let fixedContentSize = NSSize(width: 920, height: 600)
        serverContentSize = fixedContentSize
        window.setContentSize(fixedContentSize)
        window.contentMinSize = fixedContentSize
        window.contentMaxSize = fixedContentSize
    }

    private func resizeWindow(for section: AppSection) {
        guard window != nil else { return }

        let targetSize = serverContentSize

        guard window.contentView?.frame.size != targetSize else { return }

        let currentFrame = window.frame
        let contentRect = NSRect(origin: .zero, size: targetSize)
        var targetFrame = window.frameRect(forContentRect: contentRect)
        targetFrame.origin.x = currentFrame.midX - targetFrame.width / 2
        targetFrame.origin.y = currentFrame.maxY - targetFrame.height

        if let visibleFrame = window.screen?.visibleFrame ?? NSScreen.main?.visibleFrame {
            if targetFrame.minX < visibleFrame.minX {
                targetFrame.origin.x = visibleFrame.minX
            }
            if targetFrame.maxX > visibleFrame.maxX {
                targetFrame.origin.x -= targetFrame.maxX - visibleFrame.maxX
            }
            if targetFrame.minY < visibleFrame.minY {
                targetFrame.origin.y = visibleFrame.minY
            }
            if targetFrame.maxY > visibleFrame.maxY {
                targetFrame.origin.y -= targetFrame.maxY - visibleFrame.maxY
            }
        }

        let currentContentSize = window.contentLayoutRect.size
        window.contentMinSize = NSSize(
            width: min(currentContentSize.width, targetSize.width),
            height: min(currentContentSize.height, targetSize.height)
        )
        window.contentMaxSize = NSSize(
            width: max(currentContentSize.width, targetSize.width),
            height: max(currentContentSize.height, targetSize.height)
        )

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.28
            context.timingFunction = CAMediaTimingFunction(
                name: .easeInEaseOut
            )
            window.animator().setFrame(targetFrame, display: true)
        } completionHandler: { [weak self] in
            Task { @MainActor in
                guard
                    let self,
                    self.mainWindowModel.selectedSection == section
                else {
                    return
                }
                self.window.contentMinSize = targetSize
                self.window.contentMaxSize = targetSize
            }
        }
    }

    private func buildMainMenu() {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)

        let appMenu = NSMenu()
        let aboutItem = appMenu.addItem(
            withTitle: texts.about,
            action: #selector(showAboutPanel(_:)),
            keyEquivalent: ""
        )
        aboutItem.target = self
        appMenu.addItem(.separator())
        appMenu.addItem(
            withTitle: texts.quit,
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        appMenuItem.submenu = appMenu

        let editMenuItem = NSMenuItem(
            title: texts.edit,
            action: nil,
            keyEquivalent: ""
        )
        let editMenu = NSMenu(title: texts.edit)

        let undoItem = editMenu.addItem(
            withTitle: texts.undo,
            action: Selector(("undo:")),
            keyEquivalent: "z"
        )
        undoItem.keyEquivalentModifierMask = [.command]

        let redoItem = editMenu.addItem(
            withTitle: texts.redo,
            action: Selector(("redo:")),
            keyEquivalent: "z"
        )
        redoItem.keyEquivalentModifierMask = [.command, .shift]

        editMenu.addItem(.separator())

        let cutItem = editMenu.addItem(
            withTitle: texts.cut,
            action: #selector(NSText.cut(_:)),
            keyEquivalent: "x"
        )
        cutItem.keyEquivalentModifierMask = [.command]

        let copyItem = editMenu.addItem(
            withTitle: texts.copy,
            action: #selector(NSText.copy(_:)),
            keyEquivalent: "c"
        )
        copyItem.keyEquivalentModifierMask = [.command]

        let pasteItem = editMenu.addItem(
            withTitle: texts.paste,
            action: #selector(NSText.paste(_:)),
            keyEquivalent: "v"
        )
        pasteItem.keyEquivalentModifierMask = [.command]

        editMenu.addItem(.separator())

        let selectAllItem = editMenu.addItem(
            withTitle: texts.selectAll,
            action: #selector(NSText.selectAll(_:)),
            keyEquivalent: "a"
        )
        selectAllItem.keyEquivalentModifierMask = [.command]

        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)
        NSApp.mainMenu = mainMenu
    }

    private func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.toolTip = "TorrServer"
        statusItem.button?.setAccessibilityLabel("TorrServer status")
        statusItem.button?.imagePosition = .imageLeading
        statusItem.button?.imageScaling = .scaleProportionallyUpOrDown
        statusItem.button?.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)
        statusItem.button?.target = self
        statusItem.button?.action = #selector(toggleStatusPopover(_:))
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])

        popoverModel.onStart = { [weak self] in self?.startServer(nil) }
        popoverModel.onStop = { [weak self] in self?.stopServer(nil) }
        popoverModel.onOpenWeb = { [weak self] in self?.openWebUI(nil) }
        popoverModel.onShowWindow = { [weak self] in
            self?.statusPopover.performClose(nil)
            self?.showMainWindow(nil)
        }
        popoverModel.onDownload = { [weak self] in self?.downloadLatestTorrServer(nil) }
        popoverModel.onQuit = {
            NSApp.terminate(nil)
        }
        popoverModel.onQRCodeVisibilityChanged = { [weak self] in
            self?.synchronizePopoverLayout()
        }
        statusPopover = NSPopover()
        statusPopover.behavior = .transient
        statusPopover.animates = true
        statusPopover.delegate = self
        statusPopover.contentViewController = NSHostingController(
            rootView: MenuBarPopoverView(model: popoverModel)
        )

        refreshQRCode()
    }

    @objc private func toggleStatusPopover(_ sender: Any?) {
        guard let button = statusItem.button else { return }

        if statusPopover.isShown {
            statusPopover.performClose(sender)
            return
        }

        refreshQRCode()
        refreshPopoverMaterial()
        startPopoverRefreshTimer()
        synchronizePopoverLayout()
        NSApp.activate(ignoringOtherApps: true)
        statusPopover.show(
            relativeTo: button.bounds,
            of: button,
            preferredEdge: .minY
        )
        beginMonitoringPopoverDismissal()
        synchronizePopoverLayout()

        DispatchQueue.main.async { [weak self] in
            guard
                let self,
                self.statusPopover.isShown,
                let contentView = self.statusPopover.contentViewController?.view,
                let popoverWindow = contentView.window
            else {
                return
            }

            popoverWindow.makeKey()
            popoverWindow.makeFirstResponder(contentView)
        }
    }

    func popoverDidClose(_ notification: Notification) {
        popoverRefreshTimer?.invalidate()
        popoverRefreshTimer = nil
        stopMonitoringPopoverDismissal()
    }

    private func beginMonitoringPopoverDismissal() {
        stopMonitoringPopoverDismissal()

        localPopoverEventMonitor = NSEvent.addLocalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] event in
            guard
                let self,
                self.statusPopover.isShown
            else {
                return event
            }

            let popoverWindow = self.statusPopover.contentViewController?.view.window
            let statusItemWindow = self.statusItem.button?.window
            if event.window === popoverWindow || event.window === statusItemWindow {
                return event
            }

            self.statusPopover.performClose(nil)
            return event
        }

        globalPopoverEventMonitor = NSEvent.addGlobalMonitorForEvents(
            matching: [.leftMouseDown, .rightMouseDown]
        ) { [weak self] _ in
            DispatchQueue.main.async {
                guard self?.statusPopover.isShown == true else { return }
                self?.statusPopover.performClose(nil)
            }
        }
    }

    private func stopMonitoringPopoverDismissal() {
        if let localPopoverEventMonitor {
            NSEvent.removeMonitor(localPopoverEventMonitor)
            self.localPopoverEventMonitor = nil
        }

        if let globalPopoverEventMonitor {
            NSEvent.removeMonitor(globalPopoverEventMonitor)
            self.globalPopoverEventMonitor = nil
        }
    }

    private func startPopoverRefreshTimer() {
        popoverRefreshTimer?.invalidate()
        popoverRefreshTimer = Timer.scheduledTimer(
            withTimeInterval: 2,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshPopoverMaterial()
            }
        }
    }

    private func synchronizePopoverLayout() {
        guard
            statusPopover != nil,
            let contentView = statusPopover.contentViewController?.view
        else {
            return
        }

        contentView.layoutSubtreeIfNeeded()
        let fittingSize = contentView.fittingSize
        if fittingSize.width > 0, fittingSize.height > 0 {
            statusPopover.contentSize = fittingSize
        }

        guard statusPopover.isShown else { return }

        DispatchQueue.main.async { [weak self] in
            guard
                let self,
                let popoverWindow = self.statusPopover.contentViewController?.view.window,
                let button = self.statusItem.button,
                let screen = button.window?.screen ?? popoverWindow.screen ?? NSScreen.main
            else {
                return
            }

            var frame = popoverWindow.frame
            let horizontalMargin: CGFloat = 4
            let verticalMargin: CGFloat = 4
            let minimumY = screen.visibleFrame.minY + verticalMargin
            let maximumY = screen.frame.maxY - verticalMargin
            let minimumX = screen.frame.minX + horizontalMargin
            let maximumX = screen.frame.maxX - horizontalMargin

            if frame.maxY > maximumY {
                frame.origin.y -= frame.maxY - maximumY
            }
            if frame.minY < minimumY {
                frame.origin.y = minimumY
            }
            if frame.minX < minimumX {
                frame.origin.x = minimumX
            }
            if frame.maxX > maximumX {
                frame.origin.x -= frame.maxX - maximumX
            }

            popoverWindow.setFrameOrigin(frame.origin)
        }
    }

    private func applyLanguage() {
        let language = currentLanguage
        let texts = self.texts

        buildMainMenu()
        window?.title = texts.title
        mainWindowModel.language = language
        popoverModel.language = language
        updateUI(for: processController.state)
        refreshSpeedDisplay()
    }

    private func refreshPopoverMaterial() {
        guard processController.isRunning else {
            currentTorrents = []
            popoverModel.isLoadingMaterial = false
            updatePopoverMaterial(with: [])
            refreshSpeedDisplay()
            return
        }

        popoverModel.isLoadingMaterial = true
        libraryClient.fetchTorrents { [weak self] result in
            guard let self else { return }
            self.popoverModel.isLoadingMaterial = false

            switch result {
            case .success(let torrents):
                self.currentTorrents = torrents
                self.updatePopoverMaterial(with: torrents)
            case .failure:
                self.currentTorrents = []
                self.updatePopoverMaterial(with: [])
            }
            self.synchronizePopoverLayout()
            self.refreshSpeedDisplay()
        }
    }

    private func refreshPlayerAvailability() {
        libraryModel.refreshDetectedPlayers()
        mainWindowModel.detectedPlayers = libraryModel.detectedPlayers
        mainWindowModel.preferredPlayer = libraryModel.playerChoice
    }

    private func refreshStorage() {
        guard !mainWindowModel.isRefreshingStorage else { return }
        mainWindowModel.isRefreshingStorage = true
        let torrents = libraryModel.torrents
        Task { [weak self] in
            guard let self else { return }
            let snapshot = await self.diagnosticsService.storageSnapshot(torrents: torrents)
            self.mainWindowModel.storage = snapshot
            self.mainWindowModel.isRefreshingStorage = false
        }
    }

    private func clearTorrServerCache() {
        guard !mainWindowModel.isClearingCache else { return }
        mainWindowModel.isClearingCache = true
        let torrents = libraryModel.torrents
        Task { [weak self] in
            guard let self else { return }
            do {
                try await self.diagnosticsService.clearCache(torrents: torrents)
                self.libraryModel.refresh(silently: true)
            } catch {
                self.showAlert(title: "TorrServer", message: error.localizedDescription)
            }
            self.mainWindowModel.isClearingCache = false
            self.refreshStorage()
        }
    }

    private func checkTorrServerPort() {
        mainWindowModel.portDiagnostic = DiagnosticResult(
            kind: .checking,
            message: ""
        )
        mainWindowModel.latestDiagnostic = mainWindowModel.portDiagnostic
        Task { [weak self] in
            guard let self else { return }
            self.mainWindowModel.portDiagnostic = await self.diagnosticsService.checkPort(
                language: self.currentLanguage
            )
            self.mainWindowModel.latestDiagnostic = self.mainWindowModel.portDiagnostic
        }
    }

    private func findOtherTorrServerProcesses() {
        mainWindowModel.processDiagnostic = DiagnosticResult(
            kind: .checking,
            message: ""
        )
        mainWindowModel.latestDiagnostic = mainWindowModel.processDiagnostic
        Task { [weak self] in
            guard let self else { return }
            self.mainWindowModel.processDiagnostic = await self.diagnosticsService
                .findTorrServerProcesses(language: self.currentLanguage)
            self.mainWindowModel.latestDiagnostic = self.mainWindowModel.processDiagnostic
        }
    }

    private func checkTorrServerExecutable() {
        mainWindowModel.executableDiagnostic = DiagnosticResult(
            kind: .checking,
            message: ""
        )
        mainWindowModel.latestDiagnostic = mainWindowModel.executableDiagnostic
        let path = executablePath
        Task { [weak self] in
            guard let self else { return }
            self.mainWindowModel.executableDiagnostic = await self.diagnosticsService
                .inspectExecutable(path: path, language: self.currentLanguage)
            self.mainWindowModel.latestDiagnostic = self.mainWindowModel.executableDiagnostic
        }
    }

    private func copyDiagnosticReport() {
        let report = diagnosticsService.report(
            status: mainWindowModel.statusText,
            tooltip: mainWindowModel.statusTooltip,
            executablePath: executablePath,
            storage: mainWindowModel.storage,
            port: mainWindowModel.portDiagnostic,
            process: mainWindowModel.processDiagnostic,
            executable: mainWindowModel.executableDiagnostic
        )
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(report, forType: .string)
    }

    private func updatePopoverMaterial(with torrents: [TorrentSummary]) {
        let active = torrents.first(where: \.isActive)
        let selected = active ?? torrents.first
        popoverModel.activeTitle = selected?.title
        popoverModel.materialIsActive = active != nil
        popoverModel.activeSizeText = selected.map {
            Self.formatFileSize($0.size)
        } ?? ""
        popoverModel.bufferProgress = selected?.bufferProgress
        popoverModel.seeders = selected?.seeders ?? 0
        popoverModel.peers = selected.map {
            max($0.activePeers, $0.totalPeers)
        } ?? 0
    }

    private func refreshQRCode() {
        let localURL = LocalWebUIAddress.url()
        popoverModel.webUIAddress = localURL.absoluteString
        popoverModel.qrImage = QRCodeGenerator.image(for: localURL.absoluteString)
    }

    private func updateUI(for state: TorrServerProcessController.State) {
        let hasPath = hasExecutablePath
        updateSpeedMonitor(for: state)

        if isDownloading {
            applyUIState(
                dotColor: .systemOrange,
                statusText: texts.downloading,
                statusTooltip: texts.downloading,
                canStart: false,
                canStop: false,
                canBrowse: false,
                canDownload: false,
                canOpenWeb: false,
                canEditPath: false,
                menuStatus: texts.downloading,
                statusIconColor: .systemGray
            )
            return
        }

        switch state {
        case .stopped:
            applyUIState(
                dotColor: .systemGray,
                statusText: hasPath ? texts.stopped : texts.chooseOrDownload,
                statusTooltip: hasPath ? texts.stopped : texts.chooseOrDownload,
                canStart: hasPath,
                canStop: false,
                canBrowse: true,
                canDownload: true,
                canOpenWeb: true,
                canEditPath: true,
                menuStatus: hasPath ? texts.stopped : texts.torrServerNotSelected,
                statusIconColor: .systemGray
            )

        case .running(let pid):
            applyUIState(
                dotColor: .systemGreen,
                statusText: texts.running(pid: pid),
                statusTooltip: texts.running(pid: pid),
                canStart: false,
                canStop: true,
                canBrowse: false,
                canDownload: false,
                canOpenWeb: true,
                canEditPath: false,
                menuStatus: texts.running(pid: pid),
                statusIconColor: .systemGreen
            )
            refreshStorage()

        case .stopping:
            applyUIState(
                dotColor: .systemOrange,
                statusText: texts.stopping,
                statusTooltip: texts.stopping,
                canStart: false,
                canStop: false,
                canBrowse: false,
                canDownload: false,
                canOpenWeb: false,
                canEditPath: false,
                menuStatus: texts.stopping,
                statusIconColor: .systemGray
            )

        case .failed(let message):
            applyUIState(
                dotColor: .systemRed,
                statusText: texts.error(message),
                statusTooltip: texts.errorTooltip(message),
                canStart: hasPath,
                canStop: false,
                canBrowse: true,
                canDownload: true,
                canOpenWeb: true,
                canEditPath: true,
                menuStatus: texts.launchError,
                statusIconColor: .systemGray
            )
        }
    }

    private func updateSpeedMonitor(for state: TorrServerProcessController.State) {
        let shouldRun: Bool
        if case .running = state {
            shouldRun = true
        } else {
            shouldRun = false
        }

        if shouldRun {
            speedMonitor.start()
            startMenuBarMaterialTimer()
        } else {
            speedMonitor.stop()
            menuBarMaterialTimer?.invalidate()
            menuBarMaterialTimer = nil
            currentSpeedBytesPerSecond = nil
            speedHistory.removeAll()
            popoverModel.speedSamples = []
            updatePopoverMaterial(with: [])
        }
    }

    private func startMenuBarMaterialTimer() {
        guard menuBarMaterialTimer == nil else { return }
        refreshPopoverMaterial()
        menuBarMaterialTimer = Timer.scheduledTimer(
            withTimeInterval: 2,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                self?.refreshPopoverMaterial()
            }
        }
    }

    private func recordSpeedSample(_ speed: Double?) {
        currentSpeedBytesPerSecond = speed

        if processController.isRunning {
            speedHistory.append(max(speed ?? 0, 0))
            if speedHistory.count > 30 {
                speedHistory.removeFirst(speedHistory.count - 30)
            }
        }

        popoverModel.speedSamples = speedHistory
        refreshSpeedDisplay()
    }

    private func handleNotification(for state: TorrServerProcessController.State) {
        switch state {
        case .running:
            guard !hasAnnouncedRunningState else { return }
            hasAnnouncedRunningState = true
            notificationController.send(
                title: texts.serverStartedNotificationTitle,
                body: texts.serverStartedNotificationMessage
            )

        case .failed(let message):
            hasAnnouncedRunningState = false
            notificationController.send(
                title: texts.errorNotificationTitle,
                body: message
            )

        case .stopped:
            hasAnnouncedRunningState = false

        case .stopping:
            break
        }
    }

    private func applyUIState(
        dotColor: NSColor,
        statusText: String,
        statusTooltip: String,
        canStart: Bool,
        canStop: Bool,
        canBrowse: Bool,
        canDownload: Bool,
        canOpenWeb: Bool,
        canEditPath: Bool,
        menuStatus: String,
        statusIconColor: NSColor
    ) {
        mainWindowModel.statusKind = mainStatusKind(for: dotColor)
        mainWindowModel.statusText = statusText
        mainWindowModel.statusTooltip = statusTooltip
        mainWindowModel.canStart = canStart
        mainWindowModel.canStop = canStop
        mainWindowModel.canOpenWeb = canOpenWeb
        mainWindowModel.canBrowse = canBrowse
        mainWindowModel.canDownload = canDownload
        mainWindowModel.canEditPath = canEditPath
        mainWindowModel.launchAtLogin = launchAtLoginController.isEnabled
        mainWindowModel.autoStartServer = UserDefaults.standard.bool(forKey: autoStartServerKey)
        mainWindowModel.showSpeed = isSpeedDisplayEnabled
        mainWindowModel.hideDockIcon = UserDefaults.standard.bool(forKey: hideDockIconKey)
        mainWindowModel.notificationsEnabled = UserDefaults.standard.bool(
            forKey: notificationsEnabledKey
        )
        mainWindowModel.speedUnit = currentSpeedDisplayUnit

        popoverModel.statusKind = mainStatusKind(for: dotColor)
        popoverModel.statusText = menuStatus
        popoverModel.isRunning = processController.isRunning
        popoverModel.canStart = canStart
        popoverModel.canStop = canStop
        popoverModel.canOpenWeb = canOpenWeb
        popoverModel.canDownload = canDownload
        popoverModel.isDownloading = isDownloading
        currentStatusIconColor = statusIconColor
        refreshSpeedDisplay()
    }

    private func mainStatusKind(for color: NSColor) -> MainStatusKind {
        if color == .systemGreen {
            return .running
        }
        if color == .systemOrange {
            return .working
        }
        if color == .systemRed {
            return .failed
        }
        return .stopped
    }

    private var menuBarVisualState: MenuBarVisualState {
        if isDownloading { return .updating }
        if mainWindowModel.statusKind == .failed { return .failed }
        guard processController.isRunning else { return .stopped }
        if currentTorrents.contains(where: { $0.status == 2 }) { return .buffering }
        if currentTorrents.contains(where: { $0.status == 3 })
            || (currentSpeedBytesPerSecond ?? 0) > 0 {
            return .streaming
        }
        return .running
    }

    private func makeMenuBarImage(
        state: MenuBarVisualState,
        phase: CGFloat
    ) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()

        let color: NSColor
        switch state {
        case .stopped: color = .systemGray
        case .running, .streaming: color = .systemGreen
        case .buffering, .updating: color = .systemOrange
        case .failed: color = .systemRed
        }

        let pulse = state == .streaming ? (0.22 + phase * 0.13) : 0.18
        let glowRect = NSRect(x: 1.25, y: 1.25, width: 15.5, height: 15.5)
        color.withAlphaComponent(pulse).setFill()
        NSBezierPath(ovalIn: glowRect).fill()

        let rect = NSRect(x: 2.45, y: 2.45, width: 13.1, height: 13.1)
        color.setFill()
        NSBezierPath(ovalIn: rect).fill()

        NSColor.white.withAlphaComponent(0.95).setFill()
        let bolt = NSBezierPath()
        bolt.move(to: NSPoint(x: 10.1, y: 14.1))
        bolt.line(to: NSPoint(x: 6.25, y: 9.25))
        bolt.line(to: NSPoint(x: 8.65, y: 9.25))
        bolt.line(to: NSPoint(x: 7.65, y: 4.35))
        bolt.line(to: NSPoint(x: 12.15, y: 9.85))
        bolt.line(to: NSPoint(x: 9.75, y: 9.85))
        bolt.close()
        bolt.fill()

        if state == .updating {
            let ringRect = NSRect(x: 0.8, y: 0.8, width: 16.4, height: 16.4)
            let ring = NSBezierPath()
            ring.appendArc(
                withCenter: NSPoint(x: ringRect.midX, y: ringRect.midY),
                radius: ringRect.width / 2,
                startAngle: 90 - phase * 360,
                endAngle: 220 - phase * 360
            )
            ring.lineWidth = 1.2
            ring.lineCapStyle = .round
            NSColor.white.withAlphaComponent(0.9).setStroke()
            ring.stroke()
        }

        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    private func refreshSpeedDisplay() {
        guard statusItem != nil else { return }

        let isServerRunning = processController.isRunning
        let speedText = currentSpeedBytesPerSecond.map {
            SpeedFormatter.string(
                bytesPerSecond: $0,
                unit: currentSpeedDisplayUnit
            )
        } ?? SpeedFormatter.string(
            bytesPerSecond: 0,
            unit: currentSpeedDisplayUnit
        )
        popoverModel.speedText = speedText
        popoverModel.speedSamples = speedHistory

        let shouldShowSpeed = isSpeedDisplayEnabled
            && isServerRunning
            && (currentSpeedBytesPerSecond ?? 0) > 0
        let title = shouldShowSpeed
            ? currentSpeedBytesPerSecond.map {
                SpeedFormatter.string(
                    bytesPerSecond: $0,
                    unit: currentSpeedDisplayUnit
                )
            } ?? ""
            : ""

        statusItem.length = title.isEmpty
            ? NSStatusItem.squareLength
            : NSStatusItem.variableLength
        updateMenuBarAnimationTimer()
        statusItem.button?.image = makeMenuBarImage(
            state: menuBarVisualState,
            phase: menuBarAnimationPhase
        )
        statusItem.button?.title = title.isEmpty ? "" : " \(title)"
        statusItem.button?.toolTip = title.isEmpty
            ? "TorrServer"
            : "TorrServer · \(title)"
    }

    private func updateMenuBarAnimationTimer() {
        let state = menuBarVisualState
        let needsAnimation = state == .streaming || state == .updating
        guard needsAnimation else {
            menuBarAnimationTimer?.invalidate()
            menuBarAnimationTimer = nil
            menuBarAnimationPhase = 0
            return
        }
        guard menuBarAnimationTimer == nil else { return }
        let interval: TimeInterval = state == .updating ? 0.14 : 0.8
        menuBarAnimationTimer = Timer.scheduledTimer(
            withTimeInterval: interval,
            repeats: true
        ) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }
                self.menuBarAnimationPhase += state == .updating ? 0.08 : 1
                if self.menuBarAnimationPhase > 1 {
                    self.menuBarAnimationPhase = 0
                }
                self.statusItem.button?.image = self.makeMenuBarImage(
                    state: self.menuBarVisualState,
                    phase: self.menuBarAnimationPhase
                )
            }
        }
    }

    private static func formatFileSize(_ bytes: Int64) -> String {
        guard bytes > 0 else { return "0 MB" }

        let value = Double(bytes)
        if value >= 1024 * 1024 * 1024 {
            return String(format: "%.1f GB", value / 1024 / 1024 / 1024)
        }

        return String(format: "%.0f MB", value / 1024 / 1024)
    }

    private func saveCurrentPath() {
        UserDefaults.standard.set(executablePath, forKey: savedPathKey)
    }

    private func showAlert(title: String, message: String) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = title
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.runModal()
    }
}

let app = NSApplication.shared
let appDelegate = MainActor.assumeIsolated {
    AppDelegate()
}
app.delegate = appDelegate
app.run()
