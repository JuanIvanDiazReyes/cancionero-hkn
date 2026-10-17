import SwiftData
import SwiftUI

@main
struct CancioneroHKNApp: App {
    var body: some Scene {
        WindowGroup {
            SongListView(library: LibraryStore.shared.library)
        }
        .modelContainer(for: SongSettingsRecord.self)
    }
}
