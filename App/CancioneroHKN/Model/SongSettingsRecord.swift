import CancioneroCore
import Foundation
import SwiftData

/// Tono, cejilla y sostenidos/bemoles que el usuario eligió para una canción.
/// Se guarda en el teléfono con SwiftData y sobrevive a reinicios de la app.
@Model
final class SongSettingsRecord {
    @Attribute(.unique) var songID: String
    var transpose: Int
    var capo: Int?
    var accidentalsRaw: String?

    init(songID: String) {
        self.songID = songID
        self.transpose = 0
        self.capo = nil
        self.accidentalsRaw = nil
    }

    var settings: ChordSettings {
        get {
            ChordSettings(transpose: transpose, capo: capo,
                          accidentals: accidentalsRaw.flatMap(Accidentals.init(rawValue:)))
        }
        set {
            transpose = newValue.transpose
            capo = newValue.capo
            accidentalsRaw = newValue.accidentals?.rawValue
        }
    }
}
