import Foundation

/// Cambios pequeños sobre una línea con letra: cambiar, mover, añadir o quitar acordes
/// y corregir la letra sin perder los acordes.
public extension SongLine {
    var chordCount: Int {
        switch self {
        case let .lyric(_, chords): return chords.count
        case let .instrumental(_, chords, _): return chords.count
        case .directive: return 0
        }
    }

    /// Texto que se ve (letra, línea de acordes o indicación).
    var displayText: String {
        switch self {
        case let .lyric(text, _): return text
        case let .instrumental(_, _, text): return text
        case let .directive(text): return text
        }
    }

    /// Cambia el nombre del acorde número `index`.
    func replacingChord(at index: Int, with chord: String) -> SongLine {
        let chord = chord.trimmingCharacters(in: .whitespaces)
        guard !chord.isEmpty else { return removingChord(at: index) }
        switch self {
        case var .lyric(text, chords) where chords.indices.contains(index):
            chords[index].chord = chord
            return .lyric(text: text, chords: chords)
        case .instrumental(_, var chords, _) where chords.indices.contains(index):
            chords[index] = chord
            return .instrumentalLine(label: instrumentalLabel, chords: chords)
        default:
            return self
        }
    }

    func removingChord(at index: Int) -> SongLine {
        switch self {
        case var .lyric(text, chords) where chords.indices.contains(index):
            chords.remove(at: index)
            return .lyric(text: text, chords: chords)
        case .instrumental(_, var chords, _) where chords.indices.contains(index):
            chords.remove(at: index)
            return .instrumentalLine(label: instrumentalLabel, chords: chords)
        default:
            return self
        }
    }

    /// Mueve un acorde `offset` letras a la izquierda (negativo) o a la derecha.
    func movingChord(at index: Int, by offset: Int) -> SongLine {
        guard case let .lyric(text, chords) = self, chords.indices.contains(index) else { return self }
        var moved = chords
        moved[index].pos = min(max(chords[index].pos + offset, 0), text.count)
        return .lyric(text: text, chords: moved.sortedByPosition())
    }

    /// Mueve un acorde al principio de la palabra anterior o siguiente.
    func movingChordByWord(at index: Int, forward: Bool) -> SongLine {
        guard case let .lyric(text, chords) = self, chords.indices.contains(index) else { return self }
        let starts = SongLine.wordStarts(in: text)
        let pos = chords[index].pos
        let target = forward
            ? starts.first { $0 > pos } ?? text.count
            : starts.last { $0 < pos } ?? 0
        return movingChord(at: index, by: target - pos)
    }

    /// Añade un acorde en la letra `pos` (o al final de una línea de acordes).
    func addingChord(_ chord: String, at pos: Int) -> SongLine {
        let chord = chord.trimmingCharacters(in: .whitespaces)
        guard !chord.isEmpty else { return self }
        switch self {
        case let .lyric(text, chords):
            let p = min(max(pos, 0), text.count)
            return .lyric(text: text, chords: (chords + [PositionedChord(pos: p, chord: chord)]).sortedByPosition())
        case let .instrumental(_, chords, _):
            return .instrumentalLine(label: instrumentalLabel, chords: chords + [chord])
        case .directive:
            return self
        }
    }

    /// Cambia la letra. Los acordes se quedan sobre las mismas palabras cuando es posible.
    func replacingLyric(with newText: String) -> SongLine {
        switch self {
        case let .lyric(oldText, chords):
            let map = SongLine.positionMap(from: Array(oldText), to: Array(newText))
            let moved = chords.map { PositionedChord(pos: map[min($0.pos, map.count - 1)], chord: $0.chord) }
            return .lyric(text: newText, chords: moved.sortedByPosition())
        case .directive:
            return .directive(text: newText)
        case .instrumental:
            return SongText.instrumental(newText)
        }
    }

    private var instrumentalLabel: String? {
        if case let .instrumental(label, _, _) = self { return label }
        return nil
    }

    private static func instrumentalLine(label: String?, chords: [String]) -> SongLine {
        let body = chords.joined(separator: " ")
        return .instrumental(label: label, chords: chords, text: label.map { "\($0): \(body)" } ?? body)
    }

    static func wordStarts(in text: String) -> [Int] {
        var starts: [Int] = []
        var previous: Character = " "
        for (i, c) in text.enumerated() {
            if !c.isWhitespace && previous.isWhitespace { starts.append(i) }
            previous = c
        }
        return starts
    }

    /// Para cada posición del texto viejo (0...count), su posición en el nuevo,
    /// siguiendo los caracteres que no cambiaron (subsecuencia común más larga).
    static func positionMap(from oldText: [Character], to newText: [Character]) -> [Int] {
        // Sin distinguir mayúsculas: "Te" → "te" sigue siendo la misma palabra.
        let old = oldText.map { $0.lowercased() }, new = newText.map { $0.lowercased() }
        let n = old.count, m = new.count
        var lcs = Array(repeating: Array(repeating: 0, count: m + 1), count: n + 1)
        for i in stride(from: n - 1, through: 0, by: -1) {
            for j in stride(from: m - 1, through: 0, by: -1) {
                lcs[i][j] = old[i] == new[j] ? lcs[i + 1][j + 1] + 1 : max(lcs[i + 1][j], lcs[i][j + 1])
            }
        }
        var map = Array(repeating: 0, count: n + 1)
        var i = 0, j = 0
        while i < n {
            if j < m && old[i] == new[j] {
                map[i] = j
                i += 1; j += 1
            } else if j < m && lcs[i][j + 1] >= lcs[i + 1][j] {
                j += 1
            } else {
                map[i] = j  // carácter borrado: el acorde pasa a lo que sigue
                i += 1
            }
        }
        map[n] = m
        return map
    }
}

private extension Array where Element == PositionedChord {
    func sortedByPosition() -> [PositionedChord] {
        enumerated().sorted { ($0.element.pos, $0.offset) < ($1.element.pos, $1.offset) }.map(\.element)
    }
}

public extension Song {
    func line(at anchor: LineAnchor) -> SongLine? {
        guard blocks.indices.contains(anchor.block),
              blocks[anchor.block].lines.indices.contains(anchor.line) else { return nil }
        return blocks[anchor.block].lines[anchor.line]
    }

    func replacingLine(at anchor: LineAnchor, with line: SongLine) -> Song {
        guard self.line(at: anchor) != nil else { return self }
        var copy = self
        copy.blocks[anchor.block].lines[anchor.line] = line
        return copy
    }

    /// Una copia independiente para editar sin tocar la original.
    func duplicated(id: String, number: Int) -> Song {
        var copy = self
        copy.id = id
        copy.number = number
        copy.title = title + " (mi versión)"
        copy.album = Song.customAlbum
        return copy
    }

    static let customAlbum = "MIS CANCIONES"
}
