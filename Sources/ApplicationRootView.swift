import SwiftUI

enum AppSection: String {
    case server
    case library
}

struct ApplicationRootView: View {
    @ObservedObject var mainModel: MainWindowModel
    @ObservedObject var libraryModel: LibraryViewModel

    var body: some View {
        Group {
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
            }
        }
        .animation(.easeInOut(duration: 0.18), value: mainModel.selectedSection)
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
        }
        .padding(3)
        .frame(width: 190, height: 32)
        .background(Color.secondary.opacity(0.10), in: Capsule())
        .overlay(Capsule().stroke(.white.opacity(0.10), lineWidth: 0.5))
    }

    private func sectionButton(
        title: String,
        systemImage: String,
        section: AppSection
    ) -> some View {
        Button {
            model.selectedSection = section
            model.onSectionChanged?(section)
        } label: {
            Label(title, systemImage: systemImage)
                .font(.system(
                    size: 11.5,
                    weight: model.selectedSection == section ? .semibold : .regular
                ))
                .foregroundStyle(
                    model.selectedSection == section ? Color.white : Color.secondary
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
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
