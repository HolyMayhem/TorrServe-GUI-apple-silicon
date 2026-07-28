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
    var onLanguageChanged: ((AppLanguage) -> Void)?
}

struct MainWindowView: View {
    @ObservedObject var model: MainWindowModel

    private var texts: Texts {
        Texts(language: model.language)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor),
                    Color.green.opacity(0.055),
                    Color(nsColor: .windowBackgroundColor)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 14) {
                    header
                    executableSection
                    actionSection
                    settingsSection
                }
                .padding(22)
                .frame(maxWidth: 620)
            }
        }
        .frame(minWidth: 530, minHeight: 470)
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

            Divider()
                .padding(.vertical, 8)

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
        Button {
            withAnimation(.easeInOut(duration: 0.22)) {
                onChange(!isOn)
            }
        } label: {
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .foregroundStyle(isOn ? .green : .secondary)
                    .frame(width: 18)

                Text(title)
                    .font(.system(size: 13))
                    .foregroundStyle(.primary)

                Spacer(minLength: 12)

                GlassSwitchTrack(isOn: isOn)
            }
            .contentShape(Rectangle())
            .padding(.vertical, 6)
        }
        .buttonStyle(.plain)
        .accessibilityValue(isOn ? "On" : "Off")
    }
}

private struct GlassSwitchTrack: View {
    let isOn: Bool

    var body: some View {
        ZStack(alignment: isOn ? .trailing : .leading) {
            if #available(macOS 26.0, *) {
                Capsule()
                    .fill(isOn ? Color.green.opacity(0.24) : Color.white.opacity(0.035))
                    .glassEffect(
                        .regular
                            .tint(isOn ? Color.green.opacity(0.55) : Color.gray.opacity(0.16))
                            .interactive(),
                        in: Capsule()
                    )
            } else {
                Capsule()
                    .fill(isOn ? Color.green.opacity(0.75) : Color.secondary.opacity(0.25))
                    .overlay(Capsule().stroke(.white.opacity(0.14), lineWidth: 0.5))
            }

            Circle()
                .fill(.white)
                .shadow(color: .black.opacity(0.22), radius: 2, y: 1)
                .padding(3)
        }
        .frame(width: 46, height: 26)
    }
}

private struct GlassLanguagePicker: View {
    let language: AppLanguage
    let russianTitle: String
    let englishTitle: String
    let onChange: (AppLanguage) -> Void

    var body: some View {
        HStack(spacing: 4) {
            languageButton(title: russianTitle, value: .russian)
            languageButton(title: englishTitle, value: .english)
        }
        .padding(3)
        .adaptiveGlass(in: Capsule())
    }

    @ViewBuilder
    private func languageButton(title: String, value: AppLanguage) -> some View {
        let isSelected = language == value

        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                onChange(value)
            }
        } label: {
            Text(title)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                .frame(minWidth: 70)
                .padding(.horizontal, 5)
                .padding(.vertical, 5)
                .background {
                    if isSelected {
                        Capsule()
                            .fill(Color.green.opacity(0.22))
                    }
                }
        }
        .buttonStyle(.plain)
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
