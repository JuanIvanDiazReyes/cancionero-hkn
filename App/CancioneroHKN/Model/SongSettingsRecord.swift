import CancioneroCore
import Foundation
import SwiftData

/// Tono, cejilla, sostenidos/bemoles, tempo y notas de arreglo de una canción.
/// Se guarda en el teléfono con SwiftData y sobrevive a reinicios de la app.
@Model
final class SongSettingsRecord {
    @Attribute(.unique) var songID: String
    var transpose: Int
    var capo: Int?
    var accidentalsRaw: String?
    /// Pulsos por minuto; `nil` = sin tempo.
    var bpm: Int? = nil
    var beatsPerBar: Int = 4
    var beatUnit: Int = 4
    /// Notas de arreglo para toda la canción (quién entra, dinámica, estructura…).
    var arrangement: String = ""

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

    var timeSignature: TimeSignature {
        get { TimeSignature(beats: beatsPerBar, unit: beatUnit) }
        set {
            beatsPerBar = newValue.beats
            beatUnit = newValue.unit
        }
    }
}
