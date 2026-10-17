import Foundation

/// Cancionero completo, tal como lo genera `tools/importer/import_songbook.py`.
public struct Songbook: Codable, Sendable {
    public var version: Int
    public var songs: [Song]

    public init(version: Int = 1, songs: [Song]) {
        self.version = version
        self.songs = songs
    }

    public static func decode(from data: Data) throws -> Songbook {
        try JSONDecoder().decode(Songbook.self, from: data)
    }
}

public struct Song: Codable, Identifiable, Hashable, Sendable {
    public var id: String
    public var number: Int
    public var title: String
    public var album: String
    /// Cejilla escrita en el cancionero original (los acordes son las posiciones con esa cejilla).
    public var capo: Int?
    /// Diagramas de acordes poco comunes, p. ej. "Am7": "x02010".
    public var chordDefinitions: [String: String]
    public var blocks: [SongBlock]

    public init(id: String, number: Int, title: String, album: String, capo: Int? = nil,
                chordDefinitions: [String: String] = [:], blocks: [SongBlock]) {
        self.id = id
        self.number = number
        self.title = title
        self.album = album
        self.capo = capo
        self.chordDefinitions = chordDefinitions
        self.blocks = blocks
    }

    /// Todo el texto cantado, para buscar por letra.
    public var lyricsText: String {
        blocks.flatMap(\.lines).compactMap { line in
            if case let .lyric(text, _) = line { return text }
            return nil
        }.joined(separator: "\n")
    }

    /// Acordes en orden de aparición (letra e instrumentales).
    public var allChords: [String] {
        blocks.flatMap(\.lines).flatMap { line -> [String] in
            switch line {
            case let .lyric(_, chords): return chords.map(\.chord)
            case let .instrumental(_, chords, _): return chords
            case .directive: return []
            }
        }
    }
}

public struct SongBlock: Codable, Hashable, Sendable {
    /// INTRO, SOLO, PUENTE… cuando el bloque es solo esa línea; si no, `nil`.
    public var label: String?
    public var lines: [SongLine]

    public init(label: String? = nil, lines: [SongLine]) {
        self.label = label
        self.lines = lines
    }
}

public struct PositionedChord: Codable, Hashable, Sendable {
    /// Índice (en caracteres) de la letra sobre el que se toca el acorde.
    public var pos: Int
    public var chord: String

    public init(pos: Int, chord: String) {
        self.pos = pos
        self.chord = chord
    }
}

public enum SongLine: Hashable, Sendable {
    case lyric(text: String, chords: [PositionedChord])
    case instrumental(label: String?, chords: [String], text: String)
    case directive(text: String)
}

extension SongLine: Codable {
    private enum CodingKeys: String, CodingKey { case type, text, chords, label }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        switch try c.decode(String.self, forKey: .type) {
        case "lyric":
            self = .lyric(text: try c.decode(String.self, forKey: .text),
                          chords: try c.decode([PositionedChord].self, forKey: .chords))
        case "instrumental":
            self = .instrumental(label: try c.decodeIfPresent(String.self, forKey: .label),
                                 chords: try c.decode([String].self, forKey: .chords),
                                 text: try c.decode(String.self, forKey: .text))
        default:
            self = .directive(text: try c.decode(String.self, forKey: .text))
        }
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        switch self {
        case let .lyric(text, chords):
            try c.encode("lyric", forKey: .type)
            try c.encode(text, forKey: .text)
            try c.encode(chords, forKey: .chords)
        case let .instrumental(label, chords, text):
            try c.encode("instrumental", forKey: .type)
            try c.encode(label, forKey: .label)
            try c.encode(chords, forKey: .chords)
            try c.encode(text, forKey: .text)
        case let .directive(text):
            try c.encode("directive", forKey: .type)
            try c.encode(text, forKey: .text)
        }
    }
}
