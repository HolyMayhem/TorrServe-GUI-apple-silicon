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
                sectionContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .clipped()
            }
            .padding(.horizontal, 17)
            .padding(.top, 6)
            .padding(.bottom, 17)
        }
        .frame(
            width: mainModel.selectedSection == .server ? 580 : 920,
            height: mainModel.selectedSection == .server ? nil : 640
        )
    }

    @ViewBuilder
    private var sectionContent: some View {
        ZStack {
            switch mainModel.selectedSection {
            case .server:
                MainWindowView(model: mainModel)
                    .transition(.opacity)
            case .library:
                LibraryView(
                    mainModel: mainModel,
                    model: libraryModel
                )
                .transition(.opacity)
            case .search:
                SearchView(
                    mainModel: mainModel,
                    model: searchModel
                )
                .transition(.opacity)
            }
        }
        .animation(
            .easeOut(duration: 0.16),
            value: mainModel.selectedSection
        )
    }

    private var applicationBackground: some View {
        ZStack {
            Rectangle()
                .fill(.ultraThinMaterial)

            LinearGradient(
                colors: [
                    Color(nsColor: .windowBackgroundColor).opacity(0.34),
                    Color.green.opacity(0.045),
                    Color(nsColor: .windowBackgroundColor).opacity(0.22)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    Color.white.opacity(0.045),
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

private struct ApplicationHeader: View {
    @ObservedObject var model: MainWindowModel

    var body: some View {
        VStack(spacing: 8) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("TorrServer")
                        .font(.system(size: 24, weight: .semibold, design: .rounded))
                        .fixedSize()
                    Text("Holy Mayhem")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .layoutPriority(2)

                Spacer(minLength: 16)

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
                .padding(.vertical, 8)
                .applicationHeaderGlass(in: Capsule())
                .layoutPriority(1)
                .help(
                    model.statusTooltip.isEmpty
                        ? model.statusText
                        : model.statusTooltip
                )
            }

            AppSectionPicker(model: model)
        }
    }
}

struct AppSectionPicker: View {
    @ObservedObject var model: MainWindowModel

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
            sectionButton(
                title: searchTitle,
                systemImage: "magnifyingglass",
                section: .search
            )
        }
        .padding(3)
        .frame(height: 32)
        .fixedSize(horizontal: true, vertical: false)
        .background(Color.secondary.opacity(0.10), in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.10), lineWidth: 0.5))
    }

    private func sectionButton(
        title: String,
        systemImage: String,
        section: AppSection
    ) -> some View {
        Button {
            guard model.selectedSection != section else { return }
            model.selectedSection = section
            model.onSectionChanged?(section)
        } label: {
            HStack(spacing: 7) {
                Image(systemName: systemImage)
                Text(title)
            }
                .font(.system(
                    size: 11,
                    weight: model.selectedSection == section ? .semibold : .regular
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
                    }
                }
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
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
