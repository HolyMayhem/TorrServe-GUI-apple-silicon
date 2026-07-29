import AppKit
import Darwin
import SwiftUI

private let webUIURL = URL(string: "http://localhost:8090")!
private let savedPathKey = "TorrServerExecutablePath"
private let autoStartServerKey = "AutoStartServerOnLaunch"
private let showSpeedInMenuBarKey = "ShowSpeedInMenuBar"
private let hideDockIconKey = "HideDockIcon"
private let languageKey = "AppLanguage"

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

struct Texts {
    let language: AppLanguage

    var about: String { language == .russian ? "О TorrServer" : "About TorrServer" }
    var quit: String { language == .russian ? "Завершить приложение" : "Quit" }
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
    var hideDockIcon: String {
        language == .russian
            ? "Показывать приложение только в меню баре"
            : "Show app in menu bar only"
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
    var speedLabel: String { language == .russian ? "Скорость" : "Speed" }
    var speedOff: String { language == .russian ? "выключена" : "off" }
    var speedNoData: String { language == .russian ? "нет данных" : "no data" }
    var materialsTitle: String { language == .russian ? "Материалы" : "Materials" }
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
    let seeders: Int
    let activePeers: Int
    let totalPeers: Int
    let timestamp: Int64
    let downloadSpeed: Double
    let uploadSpeed: Double

    var isActive: Bool {
        downloadSpeed > 0 || uploadSpeed > 0 || activePeers > 0
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
        let size = int64Value(dictionary["torrent_size"])
            ?? int64Value(dictionary["loaded_size"])
            ?? 0

        return TorrentSummary(
            title: title,
            size: size,
            seeders: intValue(dictionary["connected_seeders"]),
            activePeers: intValue(dictionary["active_peers"]),
            totalPeers: intValue(dictionary["total_peers"]),
            timestamp: int64Value(dictionary["timestamp"]) ?? 0,
            downloadSpeed: doubleValue(dictionary["download_speed"]),
            uploadSpeed: doubleValue(dictionary["upload_speed"])
        )
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

final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private let processController = TorrServerProcessController()
    private let downloader = TorrServerDownloader()
    private let launchAtLoginController = LaunchAtLoginController()
    private let speedMonitor = TorrServerSpeedMonitor()
    private let libraryClient = TorrServerLibraryClient()
    private let mainWindowModel = MainWindowModel()

    private var window: NSWindow!

    private var statusItem: NSStatusItem!
    private var statusMenuItem: NSMenuItem!
    private var speedMenuItem: NSMenuItem!
    private var materialsHeaderMenuItem: NSMenuItem!
    private var materialMenuItems: [NSMenuItem] = []
    private var materialsSeparatorMenuItem: NSMenuItem!
    private var showWindowMenuItem: NSMenuItem!
    private var startMenuItem: NSMenuItem!
    private var stopMenuItem: NSMenuItem!
    private var openWebMenuItem: NSMenuItem!
    private var downloadMenuItem: NSMenuItem!
    private var launchAtLoginMenuItem: NSMenuItem!
    private var showSpeedMenuItem: NSMenuItem!
    private var quitMenuItem: NSMenuItem!

    private var isDownloading = false
    private var hasRepliedToTermination = false
    private var currentSpeedBytesPerSecond: Double?
    private var currentStatusIconColor: NSColor = .systemGray
    private var currentTorrents: [TorrentSummary] = []

    func applicationDidFinishLaunching(_ notification: Notification) {
        registerDefaultSettings()
        applyActivationPolicy()
        buildMainMenu()
        buildStatusItem()
        buildWindow()
        applyLanguage()

        processController.onStateChange = { [weak self] state in
            self?.updateUI(for: state)
        }
        speedMonitor.onSpeedChange = { [weak self] speed in
            self?.currentSpeedBytesPerSecond = speed
            self?.refreshSpeedDisplay()
        }
        updateUI(for: .stopped)

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
            case .failure(let error):
                self.updateUI(for: self.processController.state)
                self.showAlert(
                    title: self.texts.downloadFailedTitle,
                    message: error.localizedDescription
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

    @objc private func toggleLaunchAtLogin(_ sender: Any?) {
        let nextState: Bool
        if let checkbox = sender as? NSButton {
            nextState = checkbox.state == .on
        } else {
            nextState = !launchAtLoginController.isEnabled
        }

        setLaunchAtLogin(nextState)
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

    @objc private func toggleSpeedInMenuBar(_ sender: Any?) {
        let nextState: Bool
        if let checkbox = sender as? NSButton {
            nextState = checkbox.state == .on
        } else {
            nextState = !isSpeedDisplayEnabled
        }

        setSpeedInMenuBar(nextState)
    }

    private func setSpeedInMenuBar(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: showSpeedInMenuBarKey)
        if !enabled {
            currentSpeedBytesPerSecond = nil
        }
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
        updateMaterialsMenu(with: currentTorrents)
    }

    @objc private func showAboutPanel(_ sender: Any?) {
        let version = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "1.9.1"
        let build = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleVersion"
        ) as? String ?? "11"
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
            hideDockIconKey: false
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
        mainWindowModel.onLanguageChanged = { [weak self] language in
            self?.setLanguage(language)
        }

        let hostingView = NSHostingView(
            rootView: MainWindowView(model: mainWindowModel)
        )
        window.contentView = hostingView
        hostingView.layoutSubtreeIfNeeded()

        let fixedContentSize = hostingView.fittingSize
        window.setContentSize(fixedContentSize)
        window.contentMinSize = fixedContentSize
        window.contentMaxSize = fixedContentSize
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
        NSApp.mainMenu = mainMenu
    }

    private func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.toolTip = "TorrServer"
        statusItem.button?.imagePosition = .imageLeading
        statusItem.button?.imageScaling = .scaleProportionallyUpOrDown
        statusItem.button?.font = .monospacedDigitSystemFont(ofSize: 11, weight: .medium)

        let menu = NSMenu()
        menu.delegate = self
        statusMenuItem = NSMenuItem(title: texts.stopped, action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false

        speedMenuItem = NSMenuItem(
            title: "\(texts.speedLabel): \(texts.speedNoData)",
            action: nil,
            keyEquivalent: ""
        )
        speedMenuItem.isEnabled = false

        materialsHeaderMenuItem = NSMenuItem(
            title: texts.materialsTitle,
            action: nil,
            keyEquivalent: ""
        )
        materialsHeaderMenuItem.isEnabled = false
        materialsSeparatorMenuItem = .separator()

        showWindowMenuItem = NSMenuItem(
            title: texts.showWindow,
            action: #selector(showMainWindow(_:)),
            keyEquivalent: ""
        )
        showWindowMenuItem.target = self

        startMenuItem = NSMenuItem(
            title: texts.start,
            action: #selector(startServer(_:)),
            keyEquivalent: ""
        )
        startMenuItem.target = self

        stopMenuItem = NSMenuItem(
            title: texts.stop,
            action: #selector(stopServer(_:)),
            keyEquivalent: ""
        )
        stopMenuItem.target = self

        openWebMenuItem = NSMenuItem(
            title: texts.openWebUI,
            action: #selector(openWebUI(_:)),
            keyEquivalent: ""
        )
        openWebMenuItem.target = self

        downloadMenuItem = NSMenuItem(
            title: texts.downloadMenu,
            action: #selector(downloadLatestTorrServer(_:)),
            keyEquivalent: ""
        )
        downloadMenuItem.target = self

        launchAtLoginMenuItem = NSMenuItem(
            title: texts.launchAtLogin,
            action: #selector(toggleLaunchAtLogin(_:)),
            keyEquivalent: ""
        )
        launchAtLoginMenuItem.target = self

        showSpeedMenuItem = NSMenuItem(
            title: texts.showSpeed,
            action: #selector(toggleSpeedInMenuBar(_:)),
            keyEquivalent: ""
        )
        showSpeedMenuItem.target = self

        menu.addItem(statusMenuItem)
        menu.addItem(speedMenuItem)
        menu.addItem(.separator())
        menu.addItem(materialsHeaderMenuItem)
        menu.addItem(materialsSeparatorMenuItem)
        menu.addItem(startMenuItem)
        menu.addItem(stopMenuItem)
        menu.addItem(openWebMenuItem)
        menu.addItem(.separator())
        menu.addItem(showWindowMenuItem)
        menu.addItem(downloadMenuItem)
        menu.addItem(launchAtLoginMenuItem)
        menu.addItem(showSpeedMenuItem)
        menu.addItem(.separator())
        quitMenuItem = menu.addItem(
            withTitle: texts.quit,
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: ""
        )

        statusItem.menu = menu
    }

    func menuWillOpen(_ menu: NSMenu) {
        guard menu === statusItem.menu else { return }
        refreshMaterialsMenu()
    }

    private func applyLanguage() {
        let language = currentLanguage
        let texts = self.texts

        buildMainMenu()
        window?.title = texts.title
        mainWindowModel.language = language

        showWindowMenuItem?.title = texts.showWindow
        startMenuItem?.title = texts.start
        stopMenuItem?.title = texts.stop
        openWebMenuItem?.title = texts.openWebUI
        downloadMenuItem?.title = texts.downloadMenu
        launchAtLoginMenuItem?.title = texts.launchAtLogin
        showSpeedMenuItem?.title = texts.showSpeed
        quitMenuItem?.title = texts.quit
        materialsHeaderMenuItem?.title = texts.materialsTitle
        refreshSpeedDisplay()
    }

    private func refreshMaterialsMenu() {
        guard processController.isRunning else {
            currentTorrents = []
            updateMaterialsMenu(with: [])
            return
        }

        setMaterialsLoading()
        libraryClient.fetchTorrents { [weak self] result in
            guard let self else { return }

            switch result {
            case .success(let torrents):
                self.currentTorrents = torrents
                self.updateMaterialsMenu(with: torrents)
            case .failure:
                self.currentTorrents = []
                self.updateMaterialsMenu(with: [])
            }
        }
    }

    private func setMaterialsLoading() {
        replaceMaterialMenuItems([
            disabledMenuItem(title: texts.loadingMaterials)
        ])
    }

    private func updateMaterialsMenu(with torrents: [TorrentSummary]) {
        let visible = Array(torrents.prefix(5))
        var items: [NSMenuItem]

        if visible.isEmpty {
            items = [disabledMenuItem(title: texts.noMaterials)]
        } else {
            items = visible.map { torrent in
                disabledMenuItem(title: makeMaterialMenuTitle(for: torrent))
            }
            if torrents.count > visible.count {
                items.append(disabledMenuItem(title: texts.moreMaterials(torrents.count - visible.count)))
            }
        }

        replaceMaterialMenuItems(items)
    }

    private func replaceMaterialMenuItems(_ items: [NSMenuItem]) {
        guard let menu = statusItem.menu else { return }

        materialMenuItems.forEach { menu.removeItem($0) }
        materialMenuItems = items

        let insertionIndex = menu.index(of: materialsSeparatorMenuItem)
        let index = insertionIndex == -1 ? menu.numberOfItems : insertionIndex
        for item in items.reversed() {
            menu.insertItem(item, at: index)
        }
    }

    private func disabledMenuItem(title: String) -> NSMenuItem {
        let item = NSMenuItem(title: title, action: nil, keyEquivalent: "")
        item.isEnabled = false
        return item
    }

    private func makeMaterialMenuTitle(for torrent: TorrentSummary) -> String {
        let title = Self.truncate(torrent.title, maxLength: 34)
        let size = Self.formatFileSize(torrent.size)
        let peers = max(torrent.activePeers, torrent.totalPeers)
        return "\(title) · \(size) · \(texts.seedsShort) \(torrent.seeders) · \(texts.peersShort) \(peers)"
    }

    private func updateUI(for state: TorrServerProcessController.State) {
        let hasPath = hasExecutablePath
        updateSpeedMonitor(for: state)

        if isDownloading {
            applyUIState(
                dotColor: .systemOrange,
                statusText: texts.downloading,
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
                canStart: false,
                canStop: true,
                canBrowse: false,
                canDownload: false,
                canOpenWeb: true,
                canEditPath: false,
                menuStatus: texts.running(pid: pid),
                statusIconColor: .systemGreen
            )

        case .stopping:
            applyUIState(
                dotColor: .systemOrange,
                statusText: texts.stopping,
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
        if case .running = state, isSpeedDisplayEnabled {
            shouldRun = true
        } else {
            shouldRun = false
        }

        if shouldRun {
            speedMonitor.start()
        } else {
            speedMonitor.stop()
            currentSpeedBytesPerSecond = nil
        }
    }

    private func applyUIState(
        dotColor: NSColor,
        statusText: String,
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

        statusMenuItem.title = menuStatus
        startMenuItem.isEnabled = canStart
        stopMenuItem.isEnabled = canStop
        openWebMenuItem.isEnabled = canOpenWeb
        downloadMenuItem.isEnabled = canDownload
        launchAtLoginMenuItem.state = launchAtLoginController.isEnabled ? .on : .off
        showSpeedMenuItem.state = isSpeedDisplayEnabled ? .on : .off

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

    private func makeMenuBarImage(color: NSColor) -> NSImage {
        let size = NSSize(width: 20, height: 20)
        let image = NSImage(size: size)
        image.lockFocus()

        let rect = NSRect(x: 0.75, y: 0.75, width: 18.5, height: 18.5)
        color.setFill()
        NSBezierPath(ovalIn: rect).fill()

        NSColor.white.setFill()
        let bolt = NSBezierPath()
        bolt.move(to: NSPoint(x: 11.25, y: 18))
        bolt.line(to: NSPoint(x: 4.8, y: 9.7))
        bolt.line(to: NSPoint(x: 9.1, y: 9.7))
        bolt.line(to: NSPoint(x: 7.2, y: 2.1))
        bolt.line(to: NSPoint(x: 15.3, y: 11.2))
        bolt.line(to: NSPoint(x: 10.8, y: 11.2))
        bolt.close()
        bolt.fill()

        image.unlockFocus()
        image.isTemplate = false
        return image
    }

    private func refreshSpeedDisplay() {
        guard statusItem != nil else { return }

        let isServerRunning = processController.isRunning
        let speedText: String
        if isSpeedDisplayEnabled, isServerRunning {
            speedText = currentSpeedBytesPerSecond.map(Self.formatSpeed) ?? texts.speedNoData
        } else if isSpeedDisplayEnabled {
            speedText = texts.stopped
        } else {
            speedText = texts.speedOff
        }

        speedMenuItem.title = "\(texts.speedLabel): \(speedText)"
        showSpeedMenuItem.state = isSpeedDisplayEnabled ? .on : .off

        let shouldShowSpeed = isSpeedDisplayEnabled
            && isServerRunning
            && (currentSpeedBytesPerSecond ?? 0) > 0
        let title = shouldShowSpeed
            ? currentSpeedBytesPerSecond.map(Self.formatSpeed) ?? ""
            : ""

        statusItem.length = title.isEmpty
            ? NSStatusItem.squareLength
            : NSStatusItem.variableLength
        statusItem.button?.image = makeMenuBarImage(color: currentStatusIconColor)
        statusItem.button?.title = title.isEmpty ? "" : " \(title)"
        statusItem.button?.toolTip = title.isEmpty
            ? "TorrServer"
            : "TorrServer · \(title)"
    }

    private static func formatSpeed(_ bytesPerSecond: Double) -> String {
        if bytesPerSecond >= 1024 * 1024 {
            return String(format: "%.1f MB/s", bytesPerSecond / 1024 / 1024)
        }

        return String(format: "%.0f KB/s", bytesPerSecond / 1024)
    }

    private static func formatFileSize(_ bytes: Int64) -> String {
        guard bytes > 0 else { return "0 MB" }

        let value = Double(bytes)
        if value >= 1024 * 1024 * 1024 {
            return String(format: "%.1f GB", value / 1024 / 1024 / 1024)
        }

        return String(format: "%.0f MB", value / 1024 / 1024)
    }

    private static func truncate(_ text: String, maxLength: Int) -> String {
        guard text.count > maxLength else { return text }
        return String(text.prefix(maxLength - 1)) + "…"
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
let appDelegate = AppDelegate()
app.delegate = appDelegate
app.run()
