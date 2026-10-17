import SwiftData
import SwiftUI

@main
struct CancioneroHKNApp: App {
    var body: some Scene {
        WindowGroup {
            SongListView(library: LibraryStore.shared.library)
                .tint(Theme.accent)
        }
        .modelContainer(for: [SongSettingsRecord.self, AnnotationRecord.self, DrawingRecord.self])
    }
}
