import SwiftData
import SwiftUI

@main
struct CancioneroHKNApp: App {
    var body: some Scene {
        WindowGroup {
            RootView()
                .tint(Theme.accent)
        }
        .modelContainer(for: [SongSettingsRecord.self, AnnotationRecord.self, DrawingRecord.self,
                              SongEditRecord.self])
    }
}

/// Junta el cancionero original con las canciones que el usuario editó o creó.
private struct RootView: View {
    @Query private var edits: [SongEditRecord]

    var body: some View {
        SongListView(library: LibraryStore.shared.library(with: edits))
    }
}
