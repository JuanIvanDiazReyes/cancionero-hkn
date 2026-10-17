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
                              SongEditRecord.self, FavoriteRecord.self, SetListRecord.self])
    }
}

/// Junta el cancionero original con las canciones que el usuario editó o creó.
private struct RootView: View {
    @Query private var edits: [SongEditRecord]

    var body: some View {
        SongListView(library: LibraryStore.shared.library(with: edits))
    }
}
