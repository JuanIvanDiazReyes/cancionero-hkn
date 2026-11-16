import CancioneroCore
import Foundation
import Observation

/// El cancionero base que el usuario importó (la app no trae canciones).
/// Se guarda como `cancionero.json` en Application Support; las ediciones y canciones
/// propias van aparte en SwiftData (`SongEditRecord`) y se aplican encima.
@Observable
final class LibraryStore {
    static let shared = LibraryStore()

    /// Canciones originales, sin las ediciones del usuario.
    private(set) var library: SongLibrary
    /// Nombre del último cancionero importado (p. ej. «Cancionero HKN 2026»).
    private(set) var name: String

    private struct Stored: Codable {
        var name: String
        var songs: [Song]
    }

    private static var fileURL: URL {
        URL.applicationSupportDirectory.appending(path: "cancionero.json")
    }

    private init() {
        if let data = try? Data(contentsOf: Self.fileURL),
           let stored = try? JSONDecoder().decode(Stored.self, from: data) {
            library = SongLibrary(songs: stored.songs)
            name = stored.name
        } else {
            library = SongLibrary(songs: [])
            name = "Cancionero"
        }
    }

    var isEmpty: Bool { library.songs.isEmpty }

    /// Sustituye el cancionero base y lo guarda en disco.
    func replace(songs: [Song], name: String) throws {
        let data = try JSONEncoder().encode(Stored(name: name, songs: songs))
        try FileManager.default.createDirectory(at: Self.fileURL.deletingLastPathComponent(),
                                                withIntermediateDirectories: true)
        try data.write(to: Self.fileURL, options: .atomic)
        library = SongLibrary(songs: songs)
        self.name = name
    }

    /// El cancionero con las versiones del usuario en lugar de las originales,
    /// más sus canciones propias (álbum «Mis canciones»).
    func library(with edits: [SongEditRecord]) -> SongLibrary {
        guard !edits.isEmpty else { return library }
        var byID: [String: Song] = [:]
        for record in edits {
            if let song = record.song { byID[record.songID] = song }
        }
        let baseIDs = Set(library.songs.map(\.id))
        let originals = library.songs.map { byID[$0.id] ?? $0 }
        // Canciones propias, y ediciones cuya canción original ya no está en el cancionero.
        let extras = edits.filter { $0.isCustom || !baseIDs.contains($0.songID) }.compactMap { byID[$0.songID] }
        return SongLibrary(songs: originals + extras)
    }

    func original(id: String) -> Song? { library.song(id: id) }
}
