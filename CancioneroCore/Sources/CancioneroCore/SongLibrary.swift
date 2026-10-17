import Foundation

public struct Album: Identifiable, Hashable, Sendable {
    public var id: String { name }
    public var name: String
    public var songs: [Song]
}

/// Canciones agrupadas por álbum (en el orden del cancionero) y búsqueda.
public struct SongLibrary: Sendable {
    public let songs: [Song]
    public let albums: [Album]
    private let searchIndex: [String: String]

    public init(songs: [Song]) {
        self.songs = songs.sorted { $0.number < $1.number }
        var order: [String] = []
        var byAlbum: [String: [Song]] = [:]
        for s in self.songs {
            if byAlbum[s.album] == nil { order.append(s.album) }
            byAlbum[s.album, default: []].append(s)
        }
        albums = order.map { Album(name: $0, songs: byAlbum[$0]!) }
        searchIndex = Dictionary(uniqueKeysWithValues: self.songs.map {
            ($0.id, SongLibrary.fold("\($0.number) \($0.title)\n\($0.lyricsText)"))
        })
    }

    public init(json: Data) throws {
        self.init(songs: try Songbook.decode(from: json).songs)
    }

    public func song(id: String) -> Song? { songs.first { $0.id == id } }

    /// Busca por número, título o letra, sin distinguir mayúsculas ni acentos.
    /// Primero las coincidencias en el título.
    public func search(_ query: String) -> [Song] {
        let q = SongLibrary.fold(query.trimmingCharacters(in: .whitespacesAndNewlines))
        guard !q.isEmpty else { return songs }
        if let n = Int(q) { return songs.filter { $0.number == n } }
        let matches = songs.filter { searchIndex[$0.id]?.contains(q) == true }
        let inTitle = matches.filter { SongLibrary.fold($0.title).contains(q) }
        return inTitle + matches.filter { !SongLibrary.fold($0.title).contains(q) }
    }

    static func fold(_ s: String) -> String {
        s.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "es"))
            .replacingOccurrences(of: "[^\\p{L}\\p{N}\\n ]", with: "", options: .regularExpression)
    }
}
