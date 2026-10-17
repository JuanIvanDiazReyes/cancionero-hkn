import CancioneroCore
import Foundation

/// Carga el cancionero incluido en la app (Resources/songbook.json).
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
}
