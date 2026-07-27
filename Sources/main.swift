import AppKit
import Darwin

private let webUIURL = URL(string: "http://localhost:8090")!
private let savedPathKey = "TorrServerExecutablePath"

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
            throw AppError(
                "Не удалось запустить TorrServer: \(error.localizedDescription)"
            )
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
            state = .failed(
                "Процесс завершился с кодом \(finishedTask.terminationStatus)"
            )
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

struct AppError: LocalizedError {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var errorDescription: String? { message }
}

final class AppDelegate: NSObject, NSApplicationDelegate, NSTextFieldDelegate {
    private let processController = TorrServerProcessController()

    private var window: NSWindow!
    private var pathField: NSTextField!
    private var browseButton: NSButton!
    private var startButton: NSButton!
    private var stopButton: NSButton!
    private var statusDot: StatusDotView!
    private var statusLabel: NSTextField!
    private var hasRepliedToTermination = false

    func applicationDidFinishLaunching(_ notification: Notification) {
        buildMainMenu()
        buildWindow()

        processController.onStateChange = { [weak self] state in
            self?.updateUI(for: state)
        }
        updateUI(for: .stopped)

        window.center()
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        true
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

    @objc private func startServer(_ sender: Any?) {
        saveCurrentPath()
        do {
            try processController.start(executablePath: pathField.stringValue)
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

    private func buildWindow() {
        window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 620, height: 300),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "TorrServer"
        window.isReleasedWhenClosed = false

        let contentView = NSView()
        contentView.translatesAutoresizingMaskIntoConstraints = false
        window.contentView = contentView

        let titleLabel = NSTextField(labelWithString: "Управление TorrServer")
        titleLabel.font = .systemFont(ofSize: 22, weight: .semibold)

        let pathLabel = NSTextField(labelWithString: "Исполняемый файл TorrServer")
        pathLabel.font = .systemFont(ofSize: 12, weight: .medium)

        pathField = NSTextField(
            string: UserDefaults.standard.string(forKey: savedPathKey) ?? ""
        )
        pathField.placeholderString = "Выберите скачанный файл TorrServer"
        pathField.delegate = self
        pathField.lineBreakMode = .byTruncatingMiddle
        pathField.setAccessibilityLabel("Путь к исполняемому файлу TorrServer")

        browseButton = NSButton(
            title: "Выбрать…",
            target: self,
            action: #selector(chooseExecutable(_:))
        )
        browseButton.bezelStyle = .rounded

        statusDot = StatusDotView()
        statusLabel = NSTextField(labelWithString: "Остановлен")
        statusLabel.font = .systemFont(ofSize: 13, weight: .medium)

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

        let webButton = NSButton(
            title: "Открыть Web UI",
            target: self,
            action: #selector(openWebUI(_:))
        )
        webButton.bezelStyle = .rounded

        let buttonStack = NSStackView(views: [startButton, stopButton, webButton])
        buttonStack.orientation = .horizontal
        buttonStack.spacing = 10
        buttonStack.distribution = .fillEqually

        let statusStack = NSStackView(views: [statusDot, statusLabel])
        statusStack.orientation = .horizontal
        statusStack.alignment = .centerY
        statusStack.spacing = 8

        let helpLabel = NSTextField(
            wrappingLabelWithString:
                "Путь сохранится автоматически. При выходе из приложения запущенный сервер будет остановлен."
        )
        helpLabel.textColor = .secondaryLabelColor
        helpLabel.font = .systemFont(ofSize: 11)

        [
            titleLabel, pathLabel, pathField, browseButton,
            statusStack, buttonStack, helpLabel
        ].forEach {
            $0.translatesAutoresizingMaskIntoConstraints = false
            contentView.addSubview($0)
        }

        NSLayoutConstraint.activate([
            titleLabel.topAnchor.constraint(equalTo: contentView.topAnchor, constant: 24),
            titleLabel.leadingAnchor.constraint(equalTo: contentView.leadingAnchor, constant: 28),

            pathLabel.topAnchor.constraint(equalTo: titleLabel.bottomAnchor, constant: 24),
            pathLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),

            pathField.topAnchor.constraint(equalTo: pathLabel.bottomAnchor, constant: 7),
            pathField.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            pathField.trailingAnchor.constraint(equalTo: browseButton.leadingAnchor, constant: -10),

            browseButton.centerYAnchor.constraint(equalTo: pathField.centerYAnchor),
            browseButton.trailingAnchor.constraint(equalTo: contentView.trailingAnchor, constant: -28),
            browseButton.widthAnchor.constraint(equalToConstant: 96),

            statusStack.topAnchor.constraint(equalTo: pathField.bottomAnchor, constant: 20),
            statusStack.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            statusDot.widthAnchor.constraint(equalToConstant: 12),
            statusDot.heightAnchor.constraint(equalToConstant: 12),

            buttonStack.topAnchor.constraint(equalTo: statusStack.bottomAnchor, constant: 22),
            buttonStack.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            buttonStack.trailingAnchor.constraint(equalTo: browseButton.trailingAnchor),
            buttonStack.heightAnchor.constraint(equalToConstant: 34),

            helpLabel.topAnchor.constraint(equalTo: buttonStack.bottomAnchor, constant: 18),
            helpLabel.leadingAnchor.constraint(equalTo: titleLabel.leadingAnchor),
            helpLabel.trailingAnchor.constraint(equalTo: browseButton.trailingAnchor),
            helpLabel.bottomAnchor.constraint(lessThanOrEqualTo: contentView.bottomAnchor, constant: -18)
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
            withTitle: "Завершить TorrServer",
            action: #selector(NSApplication.terminate(_:)),
            keyEquivalent: "q"
        )
        appMenuItem.submenu = appMenu
        NSApp.mainMenu = mainMenu
    }

    private func updateUI(for state: TorrServerProcessController.State) {
        let hasPath = !pathField.stringValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty

        switch state {
        case .stopped:
            statusDot.color = .systemGray
            statusLabel.stringValue = hasPath
                ? "Остановлен"
                : "Выберите файл TorrServer"
            startButton.isEnabled = hasPath
            stopButton.isEnabled = false
            browseButton.isEnabled = true
            pathField.isEnabled = true

        case .running(let pid):
            statusDot.color = .systemGreen
            statusLabel.stringValue = "Работает · PID \(pid)"
            startButton.isEnabled = false
            stopButton.isEnabled = true
            browseButton.isEnabled = false
            pathField.isEnabled = false

        case .stopping:
            statusDot.color = .systemOrange
            statusLabel.stringValue = "Останавливается…"
            startButton.isEnabled = false
            stopButton.isEnabled = false
            browseButton.isEnabled = false
            pathField.isEnabled = false

        case .failed(let message):
            statusDot.color = .systemRed
            statusLabel.stringValue = "Ошибка: \(message)"
            statusLabel.toolTip = message
            startButton.isEnabled = hasPath
            stopButton.isEnabled = false
            browseButton.isEnabled = true
            pathField.isEnabled = true
        }
    }

    private func saveCurrentPath() {
        let path = pathField.stringValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
        UserDefaults.standard.set(path, forKey: savedPathKey)
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
