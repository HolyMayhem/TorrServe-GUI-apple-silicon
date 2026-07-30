import AppKit
import SwiftUI

enum MainStatusKind {
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
    @Published var speedUnit: SpeedDisplayUnit = .automatic
    @Published var selectedSection: AppSection = .server

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
    var onSpeedUnitChanged: ((SpeedDisplayUnit) -> Void)?
    var onLanguageChanged: ((AppLanguage) -> Void)?
    var onSectionChanged: ((AppSection) -> Void)?
}

struct MainWindowView: View {
    @ObservedObject var model: MainWindowModel

    private var texts: Texts {
        Texts(language: model.language)
    }

    var body: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor).opacity(0.34),
                    Color.green.opacity(0.045),
                    Color(nsColor: .windowBackgroundColor).opacity(0.22)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            RadialGradient(
                colors: [
                    Color.white.opacity(0.045),
                    Color.clear
                ],
                center: .topLeading,
                startRadius: 0,
                endRadius: 360
            )
            .ignoresSafeArea()

            VStack(spacing: 12) {
                header
                executableSection
                actionSection
                settingsSection
            }
            .frame(maxWidth: .infinity, alignment: .top)
            .padding(.horizontal, 17)
            .padding(.top, 6)
            .padding(.bottom, 17)
        }
        .frame(width: 580)
    }

    private var header: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 3) {
                Text("TorrServer")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                Text("Holy Mayhem")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            AppSectionPicker(model: model)

            Spacer()

            HStack(spacing: 7) {
                Circle()
                    .fill(model.statusKind.color)
                    .frame(width: 10, height: 10)
                    .shadow(color: model.statusKind.color.opacity(0.45), radius: 4)

                Text(model.statusText)
                    .font(.system(size: 12.5, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .padding(.horizontal, 13)
            .padding(.vertical, 8)
            .adaptiveGlass(in: Capsule())
        }
    }

    private var executableSection: some View {
        VStack(alignment: .leading, spacing: 12) {
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
        HStack(spacing: 10) {
            GlassActionButton(
                title: texts.start,
                systemImage: "play.fill",
                isEnabled: model.canStart,
                isProminent: true,
                action: { model.onStart?() }
            )

            GlassActionButton(
                title: texts.stop,
                systemImage: "stop.fill",
                isEnabled: model.canStop,
                action: { model.onStop?() }
            )

            GlassActionButton(
                title: texts.webUI,
                systemImage: "safari",
                isEnabled: model.canOpenWeb,
                action: { model.onOpenWeb?() }
            )
        }
        .padding(4)
    }

    private var settingsSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Label(
                model.language == .russian ? "Настройки" : "Settings",
                systemImage: "switch.2"
            )
            .font(.headline)
            .padding(.bottom, 5)

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

            Divider()
                .padding(.vertical, 8)

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
            .padding(.vertical, 3)

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
        }
        .glassSection()
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
        .padding(.vertical, 3)
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
    func adaptiveGlass<S: Shape>(in shape: S) -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(.regular, in: shape)
        } else {
            self.background(.regularMaterial, in: shape)
                .overlay(shape.stroke(.white.opacity(0.12), lineWidth: 0.5))
        }
    }

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
}
