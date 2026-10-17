import CancioneroCore
import Foundation
import SwiftData

/// Una canción editada por el usuario: su versión de una canción del cancionero
/// (mismo `songID`) o una canción nueva o duplicada (`isCustom`).
@Model
final class SongEditRecord {
    @Attribute(.unique) var songID: String
    var isCustom: Bool
    /// La canción completa en JSON (mismo formato que songbook.json).
    var data: Data
    var updatedAt: Date

    init(song: Song, isCustom: Bool) {
        self.songID = song.id
        self.isCustom = isCustom
        self.data = (try? JSONEncoder().encode(song)) ?? Data()
        self.updatedAt = .now
    }

    var song: Song? {
        get { try? JSONDecoder().decode(Song.self, from: data) }
        set {
            guard let newValue, let encoded = try? JSONEncoder().encode(newValue) else { return }
            data = encoded
            updatedAt = .now
        }
    }

    /// Las canciones creadas por el usuario se numeran a partir de 1001.
    static let firstCustomNumber = 1001
}
