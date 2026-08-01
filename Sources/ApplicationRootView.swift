import SwiftUI

enum AppSection: String {
    case server
    case library
    case search
}

struct ApplicationRootView: View {
    @ObservedObject var mainModel: MainWindowModel
    @ObservedObject var libraryModel: LibraryViewModel
    @ObservedObject var searchModel: SearchViewModel

    var body: some View {
        ZStack {
            applicationBackground

            VStack(spacing: 12) {
                ApplicationHeader(model: mainModel)
                    .zIndex(100)
                sectionContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .zIndex(0)
            }
            .padding(.horizontal, 17)
            .padding(.top, 6)
            .padding(.bottom, 17)
        }
        .frame(
            minWidth: 580,
            maxWidth: .infinity,
            maxHeight: .infinity
        )
        .sheet(isPresented: $libraryModel.showsPlayerSetup) {
            PlayerSetupView(
                model: libraryModel,
                language: mainModel.language
            )
        }
    }

    @ViewBuilder
    private var sectionContent: some View {
        switch mainModel.selectedSection {
        case .server:
            MainWindowView(model: mainModel)
        case .library:
            LibraryView(
                mainModel: mainModel,
                model: libraryModel
            )
        case .search:
            SearchView(
                mainModel: mainModel,
                model: searchModel
            )
        }
    }

    private var applicationBackground: some View {
        ZStack {
            Rectangle()
                .fill(.regularMaterial)

            Color(nsColor: .windowBackgroundColor)
                .opacity(0.46)

            LinearGradient(
                colors: [
                    Color.white.opacity(0.055),
                    Color.green.opacity(0.022),
                    Color(nsColor: .windowBackgroundColor).opacity(0.14)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    Color.white.opacity(0.035),
                    Color.clear
                ],
                center: .topLeading,
                startRadius: 0,
                endRadius: 360
            )
        }
        .ignoresSafeArea()
    }
}

private struct PlayerSetupView: View {
    @ObservedObject var model: LibraryViewModel
    let language: AppLanguage

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(spacing: 12) {
                Image(systemName: "play.rectangle.on.rectangle")
                    .font(.system(size: 28))
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 3) {
                    Text(language == .russian ? "Выберите основной плеер" : "Choose your default player")
                        .font(.title3.weight(.semibold))
                    Text(language == .russian
                        ? "Его можно изменить в библиотеке в любое время."
                        : "You can change it from the library at any time.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(spacing: 8) {
                setupPlayerRow(
                    choice: .quickTime,
                    installed: true
                )
                ForEach(model.detectedPlayers) { player in
                    setupPlayerRow(
                        choice: player.choice,
                        installed: player.isInstalled
                    )
                }
            }

            HStack {
                Spacer()
                Button(language == .russian ? "Позже" : "Later") {
                    model.dismissPlayerSetup()
                }
            }
        }
        .padding(24)
        .frame(width: 470)
    }

    private func setupPlayerRow(
        choice: ExternalPlayerChoice,
        installed: Bool
    ) -> some View {
        HStack(spacing: 12) {
            Image(systemName: choice == .quickTime ? "play.rectangle" : "play.square")
                .frame(width: 28)
                .foregroundStyle(installed ? Color.accentColor : Color.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text(choice.title(language: language)).font(.headline)
                Text(installed
                    ? (language == .russian ? "Установлен" : "Installed")
                    : (language == .russian ? "Не установлен" : "Not installed"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if installed {
                Button(language == .russian ? "Выбрать" : "Select") {
                    model.setPlayer(choice, language: language)
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button(language == .russian ? "Скачать" : "Download") {
                    model.download(choice)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(12)
        .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct ApplicationHeader: View {
    @ObservedObject var model: MainWindowModel
    @State private var isHoveringStatus = false

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 3) {
                Text("TorrServer")
                    .font(.system(size: 24, weight: .semibold, design: .rounded))
                    .fixedSize()
                Button {
                    model.onOpenContacts?()
                } label: {
                    Text("Holy Mayhem")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .focusable(false)
                .accessibilityLabel(
                    model.language == .russian
                        ? "Связаться с Holy Mayhem"
                        : "Contact Holy Mayhem"
                )
            }
            .layoutPriority(3)

            AppSectionPicker(model: model)
                .layoutPriority(2)

            Spacer(minLength: 10)

            HStack(spacing: 7) {
                Circle()
                    .fill(model.statusKind.color)
                    .frame(width: 10, height: 10)
                    .shadow(
                        color: model.statusKind.color.opacity(0.45),
                        radius: 4
                    )

                Text(model.statusText)
                    .font(.system(size: 12.5, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
            }
            .fixedSize(horizontal: true, vertical: false)
            .padding(.horizontal, 13)
            .frame(height: 32)
            .applicationHeaderGlass(in: Capsule())
            .layoutPriority(1)
            .contentShape(Capsule())
            .onHover { isHoveringStatus = $0 }
            .overlay(alignment: .topTrailing) {
                if isHoveringStatus,
                   model.statusKind == .failed,
                   !model.statusTooltip.isEmpty {
                    ServerErrorTooltip(text: model.statusTooltip)
                        .offset(y: 40)
                        .transition(
                            .opacity.combined(
                                with: .scale(
                                    scale: 0.96,
                                    anchor: .topTrailing
                                )
                            )
                        )
                }
            }
            .animation(
                .easeOut(duration: 0.14),
                value: isHoveringStatus
            )
            .zIndex(10)
        }
        .zIndex(2)
    }
}

private struct ServerErrorTooltip: View {
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 9) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)

            Text(text)
                .font(.system(size: 11.5))
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .frame(width: 330, alignment: .leading)
        .background(
            .regularMaterial,
            in: RoundedRectangle(cornerRadius: 13, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .stroke(.white.opacity(0.14), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.28), radius: 14, y: 6)
        .allowsHitTesting(false)
    }
}

struct AppSectionPicker: View {
    @ObservedObject var model: MainWindowModel
    @Namespace private var selectionAnimation

    private let selectionSpring = Animation.spring(
        response: 0.32,
        dampingFraction: 0.84,
        blendDuration: 0.10
    )

    private var serverTitle: String {
        model.language == .russian ? "Сервер" : "Server"
    }

    private var libraryTitle: String {
        model.language == .russian ? "Библиотека" : "Library"
    }

    private var searchTitle: String {
        model.language == .russian ? "Поиск" : "Search"
    }

    var body: some View {
        HStack(spacing: 0) {
            sectionButton(
                title: serverTitle,
                systemImage: "bolt.horizontal.circle",
                section: .server
            )
            sectionButton(
                title: libraryTitle,
                systemImage: "film.stack",
                section: .library
            )
            if model.jackettEnabled {
                sectionButton(
                    title: searchTitle,
                    systemImage: "magnifyingglass",
                    section: .search
                )
                .transition(
                    .opacity.combined(with: .scale(scale: 0.92, anchor: .leading))
                )
            }
        }
        .padding(3)
        .frame(height: 32)
        .fixedSize(horizontal: true, vertical: false)
        .background(Color.secondary.opacity(0.10), in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.10), lineWidth: 0.5))
        .animation(selectionSpring, value: model.jackettEnabled)
    }

    private func sectionButton(
        title: String,
        systemImage: String,
        section: AppSection
    ) -> some View {
        Button {
            guard model.selectedSection != section else { return }
            withAnimation(selectionSpring) {
                model.selectedSection = section
                model.onSectionChanged?(section)
            }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: systemImage)
                Text(title)
            }
                .font(.system(
                    size: 11,
                    weight: .semibold
                ))
                .foregroundStyle(
                    model.selectedSection == section ? Color.white : Color.secondary
                )
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .padding(.horizontal, 15)
                .frame(maxHeight: .infinity)
                .background {
                    if model.selectedSection == section {
                        Capsule()
                            .fill(Color.accentColor.opacity(0.76))
                            .shadow(color: .black.opacity(0.12), radius: 2, y: 1)
                            .matchedGeometryEffect(
                                id: "activeSection",
                                in: selectionAnimation
                            )
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
        .animation(
            .easeInOut(duration: 0.18),
            value: model.selectedSection
        )
        .accessibilityAddTraits(
            model.selectedSection == section ? .isSelected : []
        )
    }
}

private extension View {
    @ViewBuilder
    func applicationHeaderGlass<S: Shape>(in shape: S) -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(.regular, in: shape)
        } else {
            self.background(.regularMaterial, in: shape)
                .overlay(shape.stroke(.white.opacity(0.12), lineWidth: 0.5))
        }
    }
}
