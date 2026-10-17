import Foundation

/// Nombre de nota: sostenidos o bemoles.
public enum Accidentals: String, Codable, CaseIterable, Sendable {
    case sharps, flats
}

public enum Note {
    static let sharpNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
    static let flatNames = ["C", "Db", "D", "Eb", "E", "F", "Gb", "G", "Ab", "A", "Bb", "B"]
    static let naturals: [Character: Int] = ["C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11]

    /// Semitono (0-11) de un nombre como "C#", "Bb" o "E".
    public static func semitone(_ name: String) -> Int? {
        guard let first = name.first, let base = naturals[first] else { return nil }
        let rest = name.dropFirst()
        switch rest {
        case "": return base
        case "#": return (base + 1) % 12
        case "b": return (base + 11) % 12
        default: return nil
        }
    }

    public static func name(_ semitone: Int, _ accidentals: Accidentals) -> String {
        let i = ((semitone % 12) + 12) % 12
        return accidentals == .flats ? flatNames[i] : sharpNames[i]
    }
}

/// Tonalidad de una canción: tónica y si es menor.
public struct Key: Hashable, Sendable {
    public var tonic: Int
    public var isMinor: Bool

    public init(tonic: Int, isMinor: Bool) {
        self.tonic = ((tonic % 12) + 12) % 12
        self.isMinor = isMinor
    }

    /// Tonalidades que se escriben con bemoles (F, Bb, Eb, Ab, Db y sus relativas menores).
    static let flatMajor: Set<Int> = [5, 10, 3, 8, 1]
    static let flatMinor: Set<Int> = [2, 7, 0, 5, 10]

    public var preferredAccidentals: Accidentals {
        (isMinor ? Key.flatMinor : Key.flatMajor).contains(tonic) ? .flats : .sharps
    }

    public func transposed(by semitones: Int) -> Key {
        Key(tonic: tonic + semitones, isMinor: isMinor)
    }

    public func name(_ accidentals: Accidentals? = nil) -> String {
        Note.name(tonic, accidentals ?? preferredAccidentals) + (isMinor ? "m" : "")
    }

    /// Tonalidad aproximada: la del primer acorde de la canción.
    public static func guess(from chords: [String]) -> Key? {
        for chord in chords {
            guard let m = Transposer.firstNote(in: chord) else { continue }
            let after = chord[m.range.upperBound...]
            let minor = after.hasPrefix("m") && !after.hasPrefix("maj")
            return Key(tonic: m.semitone, isMinor: minor)
        }
        return nil
    }
}

public enum Transposer {
    /// Sube o baja un acorde (o un riff como "DED-EDEDE") `semitones` semitonos.
    /// Cambia cada nota (letra A-G con su # o b) y conserva el resto: "D/F#" +2 → "E/G#",
    /// "Cadd9" +2 → "Dadd9".
    public static func transpose(_ chord: String, by semitones: Int, accidentals: Accidentals) -> String {
        var out = ""
        var i = chord.startIndex
        while i < chord.endIndex {
            let c = chord[i]
            if Note.naturals[c] != nil {
                var name = String(c)
                let next = chord.index(after: i)
                if next < chord.endIndex, chord[next] == "#" || chord[next] == "b" {
                    name.append(chord[next])
                    i = chord.index(after: next)
                } else {
                    i = next
                }
                if let s = Note.semitone(name) {
                    out += Note.name(s + semitones, accidentals)
                } else {
                    out += name
                }
            } else {
                out.append(c)
                i = chord.index(after: i)
            }
        }
        return out
    }

    struct NoteMatch {
        var range: Range<String.Index>
        var semitone: Int
    }

    static func firstNote(in chord: String) -> NoteMatch? {
        guard let r = chord.range(of: "[A-G](#|b)?", options: .regularExpression),
              let s = Note.semitone(String(chord[r])) else { return nil }
        return NoteMatch(range: r, semitone: s)
    }
}

/// Posiciones fáciles de guitarra para sugerir cejilla.
public enum CapoAdvisor {
    static let easyMajor: [Int] = [0, 7, 2, 9, 4]   // C, G, D, A, E
    static let easyMinor: [Int] = [9, 4, 2]          // Am, Em, Dm

    /// Cejilla (0-7) más baja con la que la tonalidad que suena se toca con posiciones fáciles.
    public static func suggestedCapo(forSounding key: Key) -> Int {
        let easy = key.isMinor ? easyMinor : easyMajor
        for capo in 0...7 where easy.contains(((key.tonic - capo) % 12 + 12) % 12) {
            return capo
        }
        return 0
    }
}
