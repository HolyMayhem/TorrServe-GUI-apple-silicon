import AppKit
import SwiftUI

enum MainStatusKind: Equatable {
    case stopped
    case running
    case working
    case failed

    var color: Color {
        switch self {
        case .stopped:
            return .secondary
        case .running:
            return .green
        case .working:
            return .orange
        case .failed:
            return .red
        }
    }
}

final class MainWindowModel: ObservableObject {
    @Published var path = ""
    @Published var language: AppLanguage = .systemDefault
    @Published var statusText = ""
    @Published var statusTooltip = ""
    @Published var statusKind: MainStatusKind = .stopped

    @Published var canStart = false
    @Published var canStop = false
    @Published var canBrowse = true
    @Published var canDownload = true
    @Published var canOpenWeb = true
    @Published var canEditPath = true

    @Published var launchAtLogin = false
    @Published var autoStartServer = false
    @Published var showSpeed = true
    @Published var hideDockIcon = false
    @Published var notificationsEnabled = false
    @Published var jackettEnabled = true
    @Published var speedUnit: SpeedDisplayUnit = .automatic
    @Published var selectedSection: AppSection = .server
    @Published var detectedPlayers: [DetectedPlayer] = []
    @Published var preferredPlayer: ExternalPlayerChoice = .quickTime
    @Published var storage = TorrServerStorageSnapshot()
    @Published var isRefreshingStorage = false
    @Published var isClearingCache = false
    @Published var portDiagnostic = DiagnosticResult.idle
    @Published var processDiagnostic = DiagnosticResult.idle
    @Published var executableDiagnostic = DiagnosticResult.idle
    @Published var latestDiagnostic = DiagnosticResult.idle

    var onPathChanged: ((String) -> Void)?
    var onChoose: (() -> Void)?
    var onDownload: (() -> Void)?
    var onStart: (() -> Void)?
    var onStop: (() -> Void)?
    var onOpenWeb: (() -> Void)?
    var onLaunchAtLoginChanged: ((Bool) -> Void)?
    var onAutoStartChanged: ((Bool) -> Void)?
    var onShowSpeedChanged: ((Bool) -> Void)?
    var onHideDockIconChanged: ((Bool) -> Void)?
    var onNotificationsChanged: ((Bool) -> Void)?
    var onJackettEnabledChanged: ((Bool) -> Void)?
    var onSpeedUnitChanged: ((SpeedDisplayUnit) -> Void)?
    var onLanguageChanged: ((AppLanguage) -> Void)?
    var onSectionChanged: ((AppSection) -> Void)?
    var onOpenIINADownload: (() -> Void)?
    var onOpenVLCDownload: (() -> Void)?
    var onOpenInfuseDownload: (() -> Void)?
    var onSelectPlayer: ((ExternalPlayerChoice) -> Void)?
    var onRefreshStorage: (() -> Void)?
    var onClearCache: (() -> Void)?
    var onCheckPort: (() -> Void)?
    var onFindTorrServer: (() -> Void)?
    var onCheckExecutable: (() -> Void)?
    var onCopyDiagnosticReport: (() -> Void)?
}

struct MainWindowView: View {
    @ObservedObject var model: MainWindowModel
    @State private var showsClearCacheConfirmation = false

    private var texts: Texts {
        Texts(language: model.language)
    }

    var body: some View {
        VStack(spacing: 10) {
            executableSection
            actionSection
            settingsSection

            HStack(alignment: .top, spacing: 10) {
                storageSection
                    .frame(maxWidth: .infinity)
                playerHelpSection
                    .frame(maxWidth: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var executableSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(
                model.language == .russian ? "Исполняемый файл" : "Executable",
                systemImage: "terminal.fill"
            )
            .font(.headline)

            TextField(
                model.language == .russian ? "Путь к TorrServer" : "Path to TorrServer",
                text: Binding(
                    get: { model.path },
                    set: { value in
                        model.path = value
                        model.onPathChanged?(value)
                    }
                )
            )
            .textFieldStyle(.roundedBorder)
            .controlSize(.large)
            .disabled(!model.canEditPath)

            HStack(spacing: 10) {
                GlassActionButton(
                    title: texts.choose,
                    systemImage: "folder",
                    isEnabled: model.canBrowse,
                    action: { model.onChoose?() }
                )

                GlassActionButton(
                    title: texts.downloadArm,
                    systemImage: "arrow.down.circle",
                    isEnabled: model.canDownload,
                    action: { model.onDownload?() }
                )
            }
        }
        .glassSection()
    }

    private var actionSection: some View {
        GeometryReader { geometry in
            let circleSize: CGFloat = 40
            let spacing: CGFloat = 10
            let buttonWidth = max(
                (geometry.size.width - circleSize - spacing * 2) / 2,
                120
            )

            HStack(spacing: spacing) {
                StartStopCircleButton(model: model, texts: texts)

                ServerActionCapsuleButton(
                    title: texts.webUI,
                    systemImage: "safari",
                    isEnabled: model.canOpenWeb,
                    action: { model.onOpenWeb?() }
                )
                .frame(width: buttonWidth, height: circleSize)

                diagnosticsMenu
                    .frame(width: buttonWidth, height: circleSize)
            }
        }
        .frame(height: 40)
        .padding(.horizontal, 4)
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            Label(
                model.language == .russian ? "Настройки" : "Settings",
                systemImage: "switch.2"
            )
            .font(.headline)

            HStack(alignment: .top, spacing: 18) {
                VStack(spacing: 0) {
                    GlassToggleRow(
                        title: texts.launchAtLogin,
                        systemImage: "person.crop.circle.badge.clock",
                        isOn: model.launchAtLogin,
                        onChange: { model.onLaunchAtLoginChanged?($0) }
                    )

                    GlassToggleRow(
                        title: texts.autoStartServer,
                        systemImage: "bolt.circle",
                        isOn: model.autoStartServer,
                        onChange: { model.onAutoStartChanged?($0) }
                    )

                    GlassToggleRow(
                        title: texts.showSpeed,
                        systemImage: "speedometer",
                        isOn: model.showSpeed,
                        onChange: { model.onShowSpeedChanged?($0) }
                    )

                    GlassToggleRow(
                        title: texts.hideDockIcon,
                        systemImage: "menubar.dock.rectangle",
                        isOn: model.hideDockIcon,
                        onChange: { model.onHideDockIconChanged?($0) }
                    )

                    GlassToggleRow(
                        title: texts.notifications,
                        systemImage: "bell.badge",
                        isOn: model.notificationsEnabled,
                        onChange: { model.onNotificationsChanged?($0) }
                    )
                }
                .frame(maxWidth: .infinity)

                Divider()
                    .frame(height: 145)

                VStack(spacing: 0) {
                    HStack {
                        Label(texts.speedFormat, systemImage: "speedometer")
                            .font(.system(size: 13, weight: .medium))

                        Spacer()

                        GlassSpeedUnitPicker(
                            unit: model.speedUnit,
                            automaticTitle: texts.automaticSpeed,
                            megabytesTitle: texts.megabytesSpeed,
                            megabitsTitle: texts.megabitsSpeed,
                            onChange: { model.onSpeedUnitChanged?($0) }
                        )
                    }
                    .frame(height: 29)

                    HStack {
                        Label(texts.languageLabel, systemImage: "globe")
                            .font(.system(size: 13, weight: .medium))

                        Spacer()

                        GlassLanguagePicker(
                            language: model.language,
                            russianTitle: texts.russian,
                            englishTitle: texts.english,
                            onChange: { model.onLanguageChanged?($0) }
                        )
                    }
                    .frame(height: 29)

                    GlassToggleRow(
                        title: texts.jackettSearch,
                        systemImage: "magnifyingglass.circle",
                        isOn: model.jackettEnabled,
                        onChange: { model.onJackettEnabledChanged?($0) }
                    )

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .glassSection()
    }

    private var diagnosticsMenu: some View {
        Menu {
            Button { model.onCheckPort?() } label: {
                Label(
                    model.language == .russian ? "Проверить порт 8090" : "Check port 8090",
                    systemImage: diagnosticResultIcon(
                        model.portDiagnostic.kind,
                        fallback: "network"
                    )
                )
            }
            .disabled(model.portDiagnostic.kind == .checking)

            Button { model.onFindTorrServer?() } label: {
                Label(
                    model.language == .russian ? "Найти процесс TorrServer" : "Find TorrServer process",
                    systemImage: diagnosticResultIcon(
                        model.processDiagnostic.kind,
                        fallback: "magnifyingglass"
                    )
                )
            }
            .disabled(model.processDiagnostic.kind == .checking)

            Button { model.onCheckExecutable?() } label: {
                Label(
                    model.language == .russian ? "Проверить исполняемый файл" : "Check executable",
                    systemImage: diagnosticResultIcon(
                        model.executableDiagnostic.kind,
                        fallback: "checkmark.shield"
                    )
                )
            }
            .disabled(model.executableDiagnostic.kind == .checking)

            Divider()

            Button { model.onDownload?() } label: {
                Label(
                    model.language == .russian ? "Скачать свежую версию" : "Download latest version",
                    systemImage: "arrow.down.circle"
                )
            }

            Button { model.onCopyDiagnosticReport?() } label: {
                Label(
                    model.language == .russian ? "Скопировать отчёт" : "Copy report",
                    systemImage: "doc.on.doc"
                )
            }

            if !model.latestDiagnostic.message.isEmpty {
                Divider()
                Text(model.latestDiagnostic.message)
            }
        } label: {
            Label(
                model.language == .russian ? "Диагностика" : "Diagnostics",
                systemImage: "stethoscope"
            )
            .font(.system(size: 13, weight: .medium))
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(Capsule())
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.visible)
        .serverActionSurface()
        .help(model.latestDiagnostic.message)
    }

    private var playerHelpSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            VStack(alignment: .leading, spacing: 3) {
                Text(texts.playerHelpTitle)
                    .font(.system(size: 12.5, weight: .semibold))

                Text(texts.playerHelpMessage)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            HStack(spacing: 8) {
                ForEach(model.detectedPlayers) { player in
                    PlayerStatusButton(
                        player: player,
                        isPreferred: model.preferredPlayer == player.choice,
                        language: model.language,
                        select: { model.onSelectPlayer?(player.choice) },
                        download: {
                            switch player.choice {
                            case .iina: model.onOpenIINADownload?()
                            case .vlc: model.onOpenVLCDownload?()
                            case .infuse: model.onOpenInfuseDownload?()
                            default: break
                            }
                        }
                    )
                }
            }
        }
        .serverBottomPanel()
    }

    private var storageSection: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Label(
                    model.language == .russian ? "Хранилище" : "Storage",
                    systemImage: "internaldrive"
                )
                .font(.headline)
                Spacer()
                Button { model.onRefreshStorage?() } label: {
                    if model.isRefreshingStorage {
                        ProgressView().controlSize(.small)
                    } else {
                        Image(systemName: "arrow.clockwise")
                    }
                }
                .buttonStyle(.plain)
                .disabled(model.isRefreshingStorage)
            }

            HStack(spacing: 18) {
                storageValue(
                    title: model.language == .russian ? "Буфер TorrServer" : "TorrServer buffer",
                    value: storageUsageText
                )
                storageValue(
                    title: model.language == .russian ? "Кеш на диске" : "Disk cache",
                    value: model.storage.diskCacheEnabled
                        ? ByteCountFormatter.string(fromByteCount: model.storage.diskCacheSize, countStyle: .file)
                        : (model.language == .russian ? "Выключен" : "Disabled")
                )
                storageValue(
                    title: model.language == .russian ? "Свободно" : "Free space",
                    value: ByteCountFormatter.string(fromByteCount: model.storage.freeDiskSpace, countStyle: .file),
                    warning: model.storage.isLowOnDiskSpace
                )
                Spacer()

                Button(role: .destructive) {
                    showsClearCacheConfirmation = true
                } label: {
                    Label(
                        model.language == .russian ? "Очистить" : "Clear",
                        systemImage: "trash"
                    )
                }
                .controlSize(.small)
                .disabled(model.isClearingCache || !model.canStop)
                .popover(isPresented: $showsClearCacheConfirmation) {
                    VStack(alignment: .leading, spacing: 12) {
                        Text(model.language == .russian ? "Очистить кеш?" : "Clear cache?")
                            .font(.headline)
                        Text(model.language == .russian
                            ? "Активные потоки будут остановлены. Материалы останутся в библиотеке."
                            : "Active streams will stop. Library items will remain.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        HStack {
                            Button(model.language == .russian ? "Отмена" : "Cancel") {
                                showsClearCacheConfirmation = false
                            }
                            Button(role: .destructive) {
                                showsClearCacheConfirmation = false
                                model.onClearCache?()
                            } label: {
                                Text(model.language == .russian ? "Очистить" : "Clear")
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding(16)
                    .frame(width: 300)
                }
            }
        }
        .serverBottomPanel()
    }

    private func storageValue(title: String, value: String, warning: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.caption2).foregroundStyle(.secondary)
            Text(value)
                .font(.caption.monospacedDigit().weight(.medium))
                .foregroundStyle(warning ? Color.orange : Color.primary)
        }
    }

    private var storageUsageText: String {
        let used = ByteCountFormatter.string(
            fromByteCount: model.storage.cacheUsed,
            countStyle: .memory
        )
        guard model.storage.cacheCapacity > 0 else { return used }
        let capacity = ByteCountFormatter.string(
            fromByteCount: model.storage.cacheCapacity,
            countStyle: .memory
        )
        return "\(used) / \(capacity)"
    }

    private func resultColor(_ kind: DiagnosticResultKind) -> Color {
        switch kind {
        case .success: return .green
        case .warning: return .orange
        case .failure: return .red
        default: return .secondary
        }
    }

    private func diagnosticResultIcon(
        _ kind: DiagnosticResultKind,
        fallback: String = "stethoscope"
    ) -> String {
        switch kind {
        case .checking: return "hourglass"
        case .success: return "checkmark.circle.fill"
        case .warning: return "exclamationmark.triangle.fill"
        case .failure: return "xmark.circle.fill"
        case .idle: return fallback
        }
    }
}

private struct PlayerStatusButton: View {
    let player: DetectedPlayer
    let isPreferred: Bool
    let language: AppLanguage
    let select: () -> Void
    let download: () -> Void

    var body: some View {
        Button(action: player.isInstalled ? select : download) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 5) {
                    Text(player.choice.title(language: language))
                        .font(.caption.weight(.semibold))
                    if isPreferred {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
                Text(status)
                    .font(.system(size: 9.5))
                    .foregroundStyle(isPreferred ? Color.green : Color.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
    }

    private var status: String {
        if isPreferred {
            return language == .russian ? "По умолчанию" : "Default"
        }
        if player.isInstalled {
            return language == .russian ? "Установлен" : "Installed"
        }
        return language == .russian ? "Скачать" : "Download"
    }
}

private struct StartStopCircleButton: View {
    @ObservedObject var model: MainWindowModel
    let texts: Texts

    private var isRunning: Bool { model.canStop }
    private var isEnabled: Bool { model.canStart || model.canStop }

    var body: some View {
        Button {
            if isRunning {
                model.onStop?()
            } else {
                model.onStart?()
            }
        } label: {
            ZStack {
                Circle()
                    .fill(Color.secondary.opacity(isEnabled ? 0.055 : 0.025))

                Image(systemName: isRunning ? "stop.fill" : "play.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(
                        isEnabled
                            ? (isRunning ? Color.red : Color.green)
                            : Color.secondary.opacity(0.45)
                    )
                    .offset(x: isRunning ? 0 : 1)
            }
            .frame(width: 40, height: 40)
            .serverCircularActionSurface(
                tint: isRunning ? .red : .green,
                isEnabled: isEnabled
            )
            .contentShape(Circle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
        .help(isRunning ? texts.stop : texts.start)
        .accessibilityLabel(isRunning ? texts.stop : texts.start)
    }
}

private struct ServerActionCapsuleButton: View {
    let title: String
    let systemImage: String
    let isEnabled: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.system(size: 13, weight: .medium))
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .serverActionSurface()
        .disabled(!isEnabled)
        .opacity(isEnabled ? 1 : 0.45)
    }
}

private struct GlassActionButton: View {
    let title: String
    let systemImage: String
    let isEnabled: Bool
    var isProminent = false
    let action: () -> Void

    var body: some View {
        Group {
            if #available(macOS 26.0, *) {
                if isProminent {
                    Button(action: action) {
                        Label(title, systemImage: systemImage)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                } else {
                    Button(action: action) {
                        Label(title, systemImage: systemImage)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glass)
                }
            } else {
                Button(action: action) {
                    Label(title, systemImage: systemImage)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .tint(isProminent ? .green : nil)
            }
        }
        .controlSize(.large)
        .disabled(!isEnabled)
    }
}

private struct GlassToggleRow: View {
    let title: String
    let systemImage: String
    let isOn: Bool
    let onChange: (Bool) -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(isOn ? Color.accentColor : Color.secondary)
                .frame(width: 18)

            Text(title)
                .font(.system(size: 13))
                .foregroundStyle(.primary)

            Spacer(minLength: 12)

            Toggle(
                "",
                isOn: Binding(
                    get: { isOn },
                    set: { newValue in
                        withAnimation(.easeInOut(duration: 0.22)) {
                            onChange(newValue)
                        }
                    }
                )
            )
            .labelsHidden()
            .toggleStyle(.switch)
            .controlSize(.small)
            .accessibilityLabel(title)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 29)
    }
}

private struct GlassLanguagePicker: View {
    let language: AppLanguage
    let russianTitle: String
    let englishTitle: String
    let onChange: (AppLanguage) -> Void

    var body: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.24)) {
                onChange(language == .russian ? .english : .russian)
            }
        } label: {
            ZStack(alignment: language == .russian ? .leading : .trailing) {
                languageTrack

                languageThumb
                    .padding(3)

                HStack(spacing: 0) {
                    languageLabel(russianTitle, value: .russian)
                    languageLabel(englishTitle, value: .english)
                }
            }
            .frame(width: 230, height: 28)
            .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(
            language == .russian ? russianTitle : englishTitle
        )
        .accessibilityHint(
            language == .russian ? englishTitle : russianTitle
        )
    }

    @ViewBuilder
    private var languageTrack: some View {
        if #available(macOS 26.0, *) {
            Capsule()
                .fill(Color.secondary.opacity(0.10))
                .glassEffect(.regular.interactive(), in: Capsule())
        } else {
            Capsule()
                .fill(Color.secondary.opacity(0.18))
                .overlay(Capsule().stroke(.white.opacity(0.12), lineWidth: 0.5))
        }
    }

    @ViewBuilder
    private var languageThumb: some View {
        let thumb = Capsule()
            .fill(Color.accentColor.opacity(0.72))
            .frame(width: 112, height: 22)

        if #available(macOS 26.0, *) {
            thumb.glassEffect(
                .regular.tint(Color.accentColor.opacity(0.45)).interactive(),
                in: Capsule()
            )
        } else {
            thumb.shadow(color: .black.opacity(0.18), radius: 2, y: 1)
        }
    }

    private func languageLabel(_ title: String, value: AppLanguage) -> some View {
        Text(title)
            .font(.system(size: 11.5, weight: language == value ? .semibold : .regular))
            .foregroundStyle(language == value ? Color.white : Color.secondary)
            .frame(maxWidth: .infinity)
    }
}

private struct GlassSpeedUnitPicker: View {
    let unit: SpeedDisplayUnit
    let automaticTitle: String
    let megabytesTitle: String
    let megabitsTitle: String
    let onChange: (SpeedDisplayUnit) -> Void

    private let width: CGFloat = 230
    private let height: CGFloat = 28
    private let inset: CGFloat = 3

    private var selectedIndex: Int {
        switch unit {
        case .automatic: return 0
        case .megabytes: return 1
        case .megabits: return 2
        }
    }

    var body: some View {
        ZStack(alignment: .leading) {
            speedTrack

            GeometryReader { geometry in
                let segmentWidth = (geometry.size.width - inset * 2) / 3

                speedThumb
                    .frame(width: segmentWidth, height: height - inset * 2)
                    .offset(
                        x: inset + CGFloat(selectedIndex) * segmentWidth,
                        y: inset
                    )
            }

            HStack(spacing: 0) {
                speedOption(automaticTitle, value: .automatic)
                speedOption(megabytesTitle, value: .megabytes)
                speedOption(megabitsTitle, value: .megabits)
            }
        }
        .frame(width: width, height: height)
        .animation(.easeInOut(duration: 0.24), value: unit)
    }

    @ViewBuilder
    private var speedTrack: some View {
        if #available(macOS 26.0, *) {
            Capsule()
                .fill(Color.secondary.opacity(0.10))
                .glassEffect(.regular.interactive(), in: Capsule())
        } else {
            Capsule()
                .fill(Color.secondary.opacity(0.18))
                .overlay(Capsule().stroke(.white.opacity(0.12), lineWidth: 0.5))
        }
    }

    @ViewBuilder
    private var speedThumb: some View {
        let thumb = Capsule()
            .fill(Color.accentColor.opacity(0.72))

        if #available(macOS 26.0, *) {
            thumb.glassEffect(
                .regular.tint(Color.accentColor.opacity(0.45)).interactive(),
                in: Capsule()
            )
        } else {
            thumb.shadow(color: .black.opacity(0.18), radius: 2, y: 1)
        }
    }

    private func speedOption(
        _ title: String,
        value: SpeedDisplayUnit
    ) -> some View {
        Button {
            onChange(value)
        } label: {
            Text(title)
                .font(.system(size: 11.5, weight: unit == value ? .semibold : .regular))
                .foregroundStyle(unit == value ? Color.white : Color.secondary)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title)
        .accessibilityAddTraits(unit == value ? .isSelected : [])
    }
}

private extension View {
    @ViewBuilder
    func glassSection() -> some View {
        let shape = RoundedRectangle(cornerRadius: 20, style: .continuous)

        if #available(macOS 26.0, *) {
            self
                .padding(16)
                .glassEffect(.regular, in: shape)
        } else {
            self
                .padding(16)
                .background(.regularMaterial, in: shape)
                .overlay(shape.stroke(.white.opacity(0.12), lineWidth: 0.5))
        }
    }

    @ViewBuilder
    func serverActionSurface() -> some View {
        let shape = Capsule()

        if #available(macOS 26.0, *) {
            self
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .glassEffect(.regular.interactive(), in: shape)
        } else {
            self
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .background(.regularMaterial, in: shape)
                .overlay(shape.stroke(.white.opacity(0.12), lineWidth: 0.5))
        }
    }

    @ViewBuilder
    func serverCircularActionSurface(tint: Color, isEnabled: Bool) -> some View {
        let shape = Circle()

        if #available(macOS 26.0, *) {
            self
                .glassEffect(
                    .regular
                        .tint(tint.opacity(isEnabled ? 0.08 : 0.02))
                        .interactive(),
                    in: shape
                )
                .overlay(
                    shape.stroke(tint.opacity(isEnabled ? 0.24 : 0.08), lineWidth: 0.6)
                )
        } else {
            self
                .background(.regularMaterial, in: shape)
                .overlay(
                    shape.stroke(tint.opacity(isEnabled ? 0.24 : 0.08), lineWidth: 0.6)
                )
        }
    }

    @ViewBuilder
    func serverBottomPanel() -> some View {
        let shape = RoundedRectangle(cornerRadius: 16, style: .continuous)

        if #available(macOS 26.0, *) {
            self
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, minHeight: 102, maxHeight: 102, alignment: .top)
                .glassEffect(.regular, in: shape)
        } else {
            self
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, minHeight: 102, maxHeight: 102, alignment: .top)
                .background(.regularMaterial, in: shape)
                .overlay(shape.stroke(.white.opacity(0.10), lineWidth: 0.5))
        }
    }
}
