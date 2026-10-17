import Foundation

/// Cómo quiere ver el usuario una canción: tono, cejilla y sostenidos/bemoles.
public struct ChordSettings: Hashable, Codable, Sendable {
    /// Semitonos que sube (o baja, si es negativo) el tono que suena respecto al original.
    public var transpose: Int
    /// Cejilla elegida; `nil` = la del cancionero original.
    public var capo: Int?
    /// `nil` = automático según la tonalidad.
    public var accidentals: Accidentals?

    public init(transpose: Int = 0, capo: Int? = nil, accidentals: Accidentals? = nil) {
        self.transpose = transpose
        self.capo = capo
        self.accidentals = accidentals
    }

    public var isDefault: Bool { transpose == 0 && capo == nil && accidentals == nil }
}

/// Una canción ya transpuesta, lista para pintar.
public struct SongPresentation: Sendable {
    public let song: Song
    public let settings: ChordSettings

    public init(song: Song, settings: ChordSettings) {
        self.song = song
        self.settings = settings
    }

    public var originalCapo: Int { song.capo ?? 0 }
    public var capo: Int { settings.capo ?? originalCapo }

    /// Tonalidad de las posiciones escritas en el cancionero original.
    public var originalShapesKey: Key? { Key.guess(from: song.allChords) }

    /// Tonalidad que suena (posiciones + cejilla), ya transpuesta.
    public var soundingKey: Key? {
        originalShapesKey?.transposed(by: originalCapo + settings.transpose)
    }

    /// Tonalidad de las posiciones que se tocan con la cejilla elegida.
    public var shapesKey: Key? { originalShapesKey?.transposed(by: shapeOffset) }

    /// Cuánto se mueven los acordes escritos.
    public var shapeOffset: Int { settings.transpose + originalCapo - capo }

    public var accidentals: Accidentals {
        settings.accidentals ?? shapesKey?.preferredAccidentals ?? .sharps
    }

    public var suggestedCapo: Int? {
        soundingKey.map { CapoAdvisor.suggestedCapo(forSounding: $0) }
    }

    public func chord(_ chord: String) -> String {
        if shapeOffset == 0 && settings.accidentals == nil { return chord }
        return Transposer.transpose(chord, by: shapeOffset, accidentals: accidentals)
    }

    public func line(_ line: SongLine) -> SongLine {
        switch line {
        case let .lyric(text, chords):
            return .lyric(text: text, chords: chords.map { PositionedChord(pos: $0.pos, chord: chord($0.chord)) })
        case let .instrumental(label, chords, text):
            let newChords = chords.map(chord)
            var newText = text
            if newChords != chords {
                // Rehace "INTRO: A E D" con los acordes nuevos.
                newText = (label.map { "\($0): " } ?? "") + newChords.joined(separator: " ")
            }
            return .instrumental(label: label, chords: newChords, text: newText)
        case .directive:
            return line
        }
    }

    public var blocks: [SongBlock] {
        song.blocks.map { SongBlock(label: $0.label, lines: $0.lines.map(line)) }
    }
}

/// Un trozo de letra con el acorde (si lo hay) que va encima de su primera letra.
public struct ChordPiece: Hashable, Sendable {
    public var chord: String?
    public var text: String
}

/// Una palabra (con su espacio final) que no se debe partir al saltar de línea.
public struct ChordWord: Hashable, Sendable {
    public var pieces: [ChordPiece]
}

public enum ChordLayout {
    /// Parte una línea en palabras y cada palabra en trozos que empiezan donde cae un acorde.
    /// Así la vista puede ajustar el texto al ancho de la pantalla sin perder la sílaba de cada acorde.
    public static func words(text: String, chords: [PositionedChord]) -> [ChordWord] {
        let chars = Array(text)
        var chordsAt: [Int: [String]] = [:]
        for c in chords {
            chordsAt[min(max(c.pos, 0), chars.count), default: []].append(c.chord)
        }

        var words: [ChordWord] = []
        var pieces: [ChordPiece] = []
        var current = ChordPiece(chord: nil, text: "")

        func flushPiece() {
            if current.chord != nil || !current.text.isEmpty { pieces.append(current) }
            current = ChordPiece(chord: nil, text: "")
        }
        func flushWord() {
            flushPiece()
            if !pieces.isEmpty { words.append(ChordWord(pieces: pieces)) }
            pieces = []
        }

        for i in 0..<chars.count {
            if let names = chordsAt[i] {
                flushPiece()
                current.chord = names.joined(separator: " ")
            }
            current.text.append(chars[i])
            // Fin de palabra: espacio seguido de algo que no es espacio.
            if chars[i] == " ", i + 1 < chars.count, chars[i + 1] != " " {
                flushWord()
            }
        }
        if let names = chordsAt[chars.count] {
            flushPiece()
            current.chord = names.joined(separator: " ")
        }
        flushWord()
        return words
    }
}
