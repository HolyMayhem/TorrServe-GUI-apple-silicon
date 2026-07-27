import AppKit
import Darwin

private let webUIURL = URL(string: "http://localhost:8090")!
private let savedPathKey = "TorrServerExecutablePath"
private let autoStartServerKey = "AutoStartServerOnLaunch"
private let showSpeedInMenuBarKey = "ShowSpeedInMenuBar"

final class StatusDotView: NSView {
    var color: NSColor = .systemGray {
        didSet { needsDisplay = true }
    }

    override var intrinsicContentSize: NSSize {
        NSSize(width: 12, height: 12)
    }

    override func draw(_ dirtyRect: NSRect) {
        color.setFill()
        NSBezierPath(ovalIn: bounds.insetBy(dx: 1, dy: 1)).fill()
    }
}

struct AppError: LocalizedError {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var errorDescription: String? { message }
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

    var isRunning: Bool {
        timer != nil
    }

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

final class AppDelegate: NSObject, NSApplicationDelegate, NSTextFieldDelegate {
    private let processController = TorrServerProcessController()
    private let downloader = TorrServerDownloader()
    private let launchAtLoginController = LaunchAtLoginController()
    private let speedMonitor = TorrServerSpeedMonitor()

    private var window: NSWindow!
    private var pathField: NSTextField!
    private var browseButton: NSButton!
    private var downloadButton: NSButton!
    private var startButton: NSButton!
    private var stopButton: NSButton!
    private var webButton: NSButton!
    private var statusDot: StatusDotView!
    private var statusLabel: NSTextField!
    private var launchAtLoginCheckbox: NSButton!
    private var autoStartCheckbox: NSButton!
    private var showSpeedCheckbox: NSButton!

    private var statusItem: NSStatusItem!
    private var statusMenuItem: NSMenuItem!
    private var speedMenuItem: NSMenuItem!
    private var showWindowMenuItem: NSMenuItem!
    private var startMenuItem: NSMenuItem!
    private var stopMenuItem: NSMenuItem!
    private var openWebMenuItem: NSMenuItem!
    private var downloadMenuItem: NSMenuItem!
    private var launchAtLoginMenuItem: NSMenuItem!
    private var showSpeedMenuItem: NSMenuItem!

    private var isDownloading = false
    private var hasRepliedToTermination = false
    private var currentSpeedBytesPerSecond: Double?
    private var currentStatusIconColor: NSColor = .systemGray

    func applicationDidFinishLaunching(_ notification: Notification) {
        registerDefaultSettings()
        buildMainMenu()
        buildStatusItem()
        buildWindow()

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

    func controlTextDidEndEditing(_ obj: Notification) {
        saveCurrentPath()
        updateUI(for: processController.state)
    }

    @objc private func chooseExecutable(_ sender: Any?) {
        let panel = NSOpenPanel()
        panel.title = "Выберите исполняемый файл TorrServer"
        panel.message = "Обычно файл называется TorrServer или TorrServer-darwin-arm64."
        panel.prompt = "Выбрать"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.treatsFilePackagesAsDirectories = false

        if panel.runModal() == .OK, let url = panel.url {
            pathField.stringValue = url.path
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
                self.pathField.stringValue = url.path
                self.saveCurrentPath()
                self.updateUI(for: self.processController.state)
                self.showAlert(
                    title: "TorrServer скачан",
                    message: "Файл сохранен и выбран автоматически."
                )
            case .failure(let error):
                self.updateUI(for: self.processController.state)
                self.showAlert(
                    title: "Не удалось скачать TorrServer",
                    message: error.localizedDescription
                )
            }
        }
    }

    @objc private func startServer(_ sender: Any?) {
        saveCurrentPath()

        guard hasExecutablePath else {
            showAlert(
                title: "Выберите TorrServer",
                message: "Сначала выберите файл вручную или скачайте последнюю версию для Apple Silicon."
            )
            return
        }

        do {
            try processController.start(executablePath: executablePath)
        } catch {
            showAlert(
                title: "TorrServer не запущен",
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

        do {
            try launchAtLoginController.setEnabled(nextState)
        } catch {
            showAlert(
                title: "Автозапуск не изменен",
                message: error.localizedDescription
            )
        }
        updateUI(for: processController.state)
    }

    @objc private func toggleAutoStartServer(_ sender: NSButton) {
        UserDefaults.standard.set(sender.state == .on, forKey: autoStartServerKey)
        updateUI(for: processController.state)
    }

    @objc private func toggleSpeedInMenuBar(_ sender: Any?) {
        let nextState: Bool
        if let checkbox = sender as? NSButton {
            nextState = checkbox.state == .on
        } else {
            nextState = !isSpeedDisplayEnabled
        }

        UserDefaults.standard.set(nextState, forKey: showSpeedInMenuBarKey)
        if !nextState {
            currentSpeedBytesPerSecond = nil
        }
        updateUI(for: processController.state)
    }

    @objc private func showAboutPanel(_ sender: Any?) {
        let version = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "1.3"
        let build = Bundle.main.object(
            forInfoDictionaryKey: "CFBundleVersion"
        ) as? String ?? "4"
        let credits = NSAttributedString(
            string: "Created for Holy Mayhem\nNative macOS GUI for TorrServer",
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
        pathField.stringValue.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var hasExecutablePath: Bool {
        !executablePath.isEmpty
    }

    private var isSpeedDisplayEnabled: Bool {
        UserDefaults.standard.bool(forKey: showSpeedInMenuBarKey)
    }

    private func registerDefaultSettings() {
        UserDefaults.standard.register(defaults: [
            showSpeedInMenuBarKey: true
        ])
    }

    private func buildWindow() {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 520, height: 294),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "TorrServer"
        window.isReleasedWhenClosed = false

        let contentView = NSView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        window.contentView = contentView

        let titleLabel = NSTextField(labelWithString: "TorrServer")
        titleLabel.font = .systemFont(ofSize: 22, weight: .semibold)

        statusDot = StatusDotView()
        statusLabel = NSTextField(labelWithString: "Остановлен")
        statusLabel.font = .systemFont(ofSize: 13, weight: .medium)

        let statusStack = NSStackView(views: [statusDot, statusLabel])
        statusStack.orientation = .horizontal
        statusStack.alignment = .centerY
        statusStack.spacing = 8

        pathField = NSTextField(
            string: UserDefaults.standard.string(forKey: savedPathKey) ?? ""
        )
        pathField.placeholderString = "Путь к TorrServer"
        pathField.delegate = self
        pathField.lineBreakMode = .byTruncatingMiddle
        pathField.setAccessibilityLabel("Путь к исполняемому файлу TorrServer")

        browseButton = NSButton(
            title: "Выбрать",
            target: self,
            action: #selector(chooseExecutable(_:))
        )
        browseButton.bezelStyle = .rounded

        downloadButton = NSButton(
            title: "Скачать ARM",
            target: self,
            action: #selector(downloadLatestTorrServer(_:))
        )
        downloadButton.bezelStyle = .rounded

        startButton = NSButton(
            title: "Запустить",
            target: self,
            action: #selector(startServer(_:))
        )
        startButton.bezelStyle = .rounded
        startButton.keyEquivalent = "\r"

        stopButton = NSButton(
            title: "Остановить",
            target: self,
            action: #selector(stopServer(_:))
        )
        stopButton.bezelStyle = .rounded

        webButton = NSButton(
            title: "Web UI",
            target: self,
            action: #selector(openWebUI(_:))
        )
        webButton.bezelStyle = .rounded

        launchAtLoginCheckbox = NSButton(
            checkboxWithTitle: "Открывать при входе в macOS",
            target: self,
            action: #selector(toggleLaunchAtLogin(_:))
        )
        launchAtLoginCheckbox.font = .systemFont(ofSize: 12)

        autoStartCheckbox = NSButton(
            checkboxWithTitle: "Запускать сервер при открытии приложения",
            target: self,
            action: #selector(toggleAutoStartServer(_:))
        )
        autoStartCheckbox.font = .systemFont(ofSize: 12)
        autoStartCheckbox.state = UserDefaults.standard.bool(forKey: autoStartServerKey)
            ? .on
            : .off

        let pathButtonsStack = NSStackView(views: [browseButton, downloadButton])
        pathButtonsStack.orientation = .horizontal
        pathButtonsStack.spacing = 8
        pathButtonsStack.distribution = .fillEqually

        let actionStack = NSStackView(views: [startButton, stopButton, webButton])
        actionStack.orientation = .horizontal
        actionStack.spacing = 8
        actionStack.distribution = .fillEqually

        [
            titleLabel, statusStack, pathField, pathButtonsStack,
            actionStack, launchAtLoginCheckbox, autoStartCheckbox
        ].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 22),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 24),

            statusStack.centerYAnchor.constraint(equalTo: titleLabel.centerYAnchor),
            statusStack.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),
            statusDot.widthAnchor.constraint(equalToConstant: 12),
            statusDot.heightAnchor.constraint(equalToConstant: 12),

            pathField.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 22),
            pathField.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            pathField.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -24),

            pathButtonsStack.topAnchor.constraint(equalTo: pathField.bottomAnchor, constant: 10),
            pathButtonsStack.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            pathButtonsStack.trailingAnchor.constraint(equalTo: pathField.trailingAnchor),
            pathButtonsStack.heightAnchor.constraint(equalToConstant: 32),

            actionStack.topAnchor.constraint(equalTo: pathButtonsStack.bottomAnchor, constant: 16),
            actionStack.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            actionStack.trailingAnchor.constraint(equalTo: pathField.trailingAnchor),
            actionStack.heightAnchor.constraint(equalToConstant: 34),

            launchAtLoginCheckbox.topAnchor.constraint(equalTo: actionStack.bottomAnchor, constant: 18),
            launchAtLoginCheckbox.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            launchAtLoginCheckbox.trailingAnchor.constraint(equalTo: pathField.trailingAnchor),

            autoStartCheckbox.topAnchor.constraint(equalTo: launchAtLoginCheckbox.bottomAnchor, constant: 6),
            autoStartCheckbox.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            autoStartCheckbox.trailingAnchor.constraint(equalTo: pathField.trailingAnchor)
        ])
    }

    private func buildMainMenu() {
        let mainMenu = NSMenu()
        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)

        let appMenu = NSMenu()
        appMenu.addItem(
            withTitle: "О TorrServer",
            action: #selector(NSApplication.orderFrontStandardAboutPanel(_:)),
            keyEquivalent: ""
        )
        appMenu.addItem(.separator())
        appMenu.addItem(
            withTitle: "Завершить приложение",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        appMenuItem.submenu = appMenu
        NSApp.mainMenu = mainMenu
    }

    private func buildStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.toolTip = "TorrServer"

        let menu = NSMenu()
        statusMenuItem = NSMenuItem(title: "Остановлен", action: nil, keyEquivalent: "")
        statusMenuItem.isEnabled = false

        showWindowMenuItem = NSMenuItem(
            title: "Показать окно",
            action: #selector(showMainWindow(_:)),
            keyEquivalent: ""
        )
        showWindowMenuItem.target = self

        startMenuItem = NSMenuItem(
            title: "Запустить",
            action: #selector(startServer(_:)),
            keyEquivalent: ""
        )
        startMenuItem.target = self

        stopMenuItem = NSMenuItem(
            title: "Остановить",
            action: #selector(stopServer(_:)),
            keyEquivalent: ""
        )
        stopMenuItem.target = self

        openWebMenuItem = NSMenuItem(
            title: "Открыть Web UI",
            action: #selector(openWebUI(_:)),
            keyEquivalent: ""
        )
        openWebMenuItem.target = self

        downloadMenuItem = NSMenuItem(
            title: "Скачать TorrServer для Apple Silicon",
            action: #selector(downloadLatestTorrServer(_:)),
            keyEquivalent: ""
        )
        downloadMenuItem.target = self

        launchAtLoginMenuItem = NSMenuItem(
            title: "Открывать при входе в macOS",
            action: #selector(toggleLaunchAtLogin(_:)),
            keyEquivalent: ""
        )
        launchAtLoginMenuItem.target = self

        menu.addItem(statusMenuItem)
        menu.addItem(.separator())
        menu.addItem(startMenuItem)
        menu.addItem(stopMenuItem)
        menu.addItem(openWebMenuItem)
        menu.addItem(.separator())
        menu.addItem(showWindowMenuItem)
        menu.addItem(downloadMenuItem)
        menu.addItem(launchAtLoginMenuItem)
        menu.addItem(.separator())
        menu.addItem(
            withTitle: "Завершить приложение",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: ""
        )

        statusItem.menu = menu
    }

    private func updateUI(for state: TorrServerProcessController.State) {
        let hasPath = hasExecutablePath

        if isDownloading {
            applyUIState(
                dotColor: .systemOrange,
                statusText: "Скачивается TorrServer…",
                canStart: false,
                canStop: false,
                canBrowse: false,
                canDownload: false,
                canOpenWeb: false,
                canEditPath: false,
                menuStatus: "Скачивается TorrServer…",
                statusIconColor: .systemOrange
            )
            return
        }

        switch state {
        case .stopped:
            applyUIState(
                dotColor: .systemGray,
                statusText: hasPath ? "Остановлен" : "Выберите или скачайте TorrServer",
                canStart: hasPath,
                canStop: false,
                canBrowse: true,
                canDownload: true,
                canOpenWeb: true,
                canEditPath: true,
                menuStatus: hasPath ? "Остановлен" : "TorrServer не выбран",
                statusIconColor: .systemGray
            )

        case .running(let pid):
            applyUIState(
                dotColor: .systemGreen,
                statusText: "Работает · PID \(pid)",
                canStart: false,
                canStop: true,
                canBrowse: false,
                canDownload: false,
                canOpenWeb: true,
                canEditPath: false,
                menuStatus: "Работает · PID \(pid)",
                statusIconColor: .systemGreen
            )

        case .stopping:
            applyUIState(
                dotColor: .systemOrange,
                statusText: "Останавливается…",
                canStart: false,
                canStop: false,
                canBrowse: false,
                canDownload: false,
                canOpenWeb: false,
                canEditPath: false,
                menuStatus: "Останавливается…",
                statusIconColor: .systemOrange
            )

        case .failed(let message):
            applyUIState(
                dotColor: .systemRed,
                statusText: "Ошибка: \(message)",
                canStart: hasPath,
                canStop: false,
                canBrowse: true,
                canDownload: true,
                canOpenWeb: true,
                canEditPath: true,
                menuStatus: "Ошибка запуска",
                statusIconColor: .systemRed
            )
            statusLabel.toolTip = message
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
        statusDot.color = dotColor
        statusLabel.stringValue = statusText
        statusLabel.toolTip = statusText

        startButton.isEnabled = canStart
        stopButton.isEnabled = canStop
        webButton.isEnabled = canOpenWeb
        browseButton.isEnabled = canBrowse
        downloadButton.isEnabled = canDownload
        pathField.isEnabled = canEditPath

        launchAtLoginCheckbox.state = launchAtLoginController.isEnabled ? .on : .off
        autoStartCheckbox.state = UserDefaults.standard.bool(forKey: autoStartServerKey)
            ? .on
            : .off

        statusMenuItem.title = menuStatus
        startMenuItem.isEnabled = canStart
        stopMenuItem.isEnabled = canStop
        openWebMenuItem.isEnabled = canOpenWeb
        downloadMenuItem.isEnabled = canDownload
        launchAtLoginMenuItem.state = launchAtLoginController.isEnabled ? .on : .off

        statusItem.button?.image = makeMenuBarImage(color: statusIconColor)
    }

    private func makeMenuBarImage(color: NSColor) -> NSImage {
        let size = NSSize(width: 18, height: 18)
        let image = NSImage(size: size)
        image.lockFocus()

        let rect = NSRect(x: 3, y: 3, width: 12, height: 12)
        color.setFill()
        NSBezierPath(roundedRect: rect, xRadius: 4, yRadius: 4).fill()

        NSColor.white.withAlphaComponent(0.95).setFill()
        let triangle = NSBezierPath()
        triangle.move(to: NSPoint(x: 7, y: 6))
        triangle.line(to: NSPoint(x: 7, y: 12))
        triangle.line(to: NSPoint(x: 12, y: 9))
        triangle.close()
        triangle.fill()

        image.unlockFocus()
        image.isTemplate = false
        return image
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
app.setActivationPolicy(.regular)
app.delegate = appDelegate
app.run()
