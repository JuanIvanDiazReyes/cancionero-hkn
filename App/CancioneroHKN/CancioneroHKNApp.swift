import SwiftData
import SwiftUI

@main
struct CancioneroHKNApp: App {
    @AppStorage(AppTheme.storageKey) private var theme = AppTheme.ocean.rawValue
    @AppStorage(Appearance.storageKey) private var appearance = Appearance.system.rawValue

    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(Theme.accent)
                .preferredColorScheme(Appearance(rawValue: appearance)?.colorScheme)
                // Los colores del tema se leen al dibujar; cambiar de tema redibuja todo.
                .id(theme)
        }
        .modelContainer(for: [SongSettingsRecord.self, AnnotationRecord.self, DrawingRecord.self,
                              SongEditRecord.self, FavoriteRecord.self, SetListRecord.self,
                              SongLinkRecord.self])
    }
}

/// Junta el cancionero importado con las canciones que el usuario editó o creó.
/// Sin canciones muestra la bienvenida con el botón de importar.
private struct RootView: View {
    @Environment(\.modelContext) private var context
    @Query private var edits: [SongEditRecord]

    var body: some View {
        let library = LibraryStore.shared.library(with: edits)
        Group {
            if library.songs.isEmpty {
                WelcomeView { title, blocks in
                    SongEditRecord.insertCustom(title: title, blocks: blocks, into: context)
                }
            } else {
                SongListView(library: library)
            }
        }
        .cteaImportFlow()
    }
}
