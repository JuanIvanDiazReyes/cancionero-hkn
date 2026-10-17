import CancioneroCore
import Foundation

/// Carga el cancionero incluido en la app (Resources/songbook.json)
/// y le aplica las ediciones y canciones nuevas del usuario.
final class LibraryStore {
    static let shared = LibraryStore()

    let library: SongLibrary

    private init() {
        guard let url = Bundle.main.url(forResource: "songbook", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let library = try? SongLibrary(json: data) else {
            fatalError("No se pudo cargar songbook.json del paquete de la app")
        }
        self.library = library
    }

    /// El cancionero con las versiones del usuario en lugar de las originales,
    /// más sus canciones propias (álbum «Mis canciones»).
    func library(with edits: [SongEditRecord]) -> SongLibrary {
        guard !edits.isEmpty else { return library }
        var byID: [String: Song] = [:]
        for record in edits {
            if let song = record.song { byID[record.songID] = song }
        }
        let originals = library.songs.map { byID[$0.id] ?? $0 }
        let customs = edits.filter(\.isCustom).compactMap { byID[$0.songID] }
        return SongLibrary(songs: originals + customs)
    }

    func original(id: String) -> Song? { library.song(id: id) }
}
