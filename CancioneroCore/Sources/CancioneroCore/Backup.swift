import Foundation

/// Copia de seguridad de todo lo que el usuario guardó en la app, en un solo archivo JSON.
/// La app convierte sus registros de SwiftData a estas estructuras y de vuelta.
public struct Backup: Codable, Equatable, Sendable {
    public static let currentVersion = 1

    public var version: Int
    public var exportedAt: Date
    public var settings: [SongSettings]
    public var annotations: [Annotation]
    public var drawings: [Drawing]
    /// Canciones editadas o creadas por el usuario.
    public var songs: [EditedSong]
    public var favorites: [String]
    public var setLists: [SetList]

    public init(exportedAt: Date = Date(), settings: [SongSettings] = [], annotations: [Annotation] = [],
                drawings: [Drawing] = [], songs: [EditedSong] = [], favorites: [String] = [],
                setLists: [SetList] = []) {
        self.version = Backup.currentVersion
        self.exportedAt = exportedAt
        self.settings = settings
        self.annotations = annotations
        self.drawings = drawings
        self.songs = songs
        self.favorites = favorites
        self.setLists = setLists
    }

    public struct SongSettings: Codable, Equatable, Sendable {
        public var songID: String
        public var transpose: Int
        public var capo: Int?
        public var accidentals: String?
        public var bpm: Int?
        public var beatsPerBar: Int
        public var beatUnit: Int
        public var arrangement: String

        public init(songID: String, transpose: Int, capo: Int?, accidentals: String?, bpm: Int?,
                    beatsPerBar: Int, beatUnit: Int, arrangement: String) {
            self.songID = songID
            self.transpose = transpose
            self.capo = capo
            self.accidentals = accidentals
            self.bpm = bpm
            self.beatsPerBar = beatsPerBar
            self.beatUnit = beatUnit
            self.arrangement = arrangement
        }
    }

    public struct Annotation: Codable, Equatable, Sendable {
        public var songID: String
        public var block: Int
        public var line: Int
        public var kind: String
        public var value: String
        public var detail: String?
        public var createdAt: Date

        public init(songID: String, block: Int, line: Int, kind: String, value: String,
                    detail: String?, createdAt: Date) {
            self.songID = songID
            self.block = block
            self.line = line
            self.kind = kind
            self.value = value
            self.detail = detail
            self.createdAt = createdAt
        }
    }

    public struct Drawing: Codable, Equatable, Sendable {
        public var songID: String
        public var block: Int
        /// Trazos de PencilKit (se guardan en base64 dentro del JSON).
        public var data: Data

        public init(songID: String, block: Int, data: Data) {
            self.songID = songID
            self.block = block
            self.data = data
        }
    }

    public struct EditedSong: Codable, Equatable, Sendable {
        public var song: Song
        public var isCustom: Bool

        public init(song: Song, isCustom: Bool) {
            self.song = song
            self.isCustom = isCustom
        }
    }

    public struct SetList: Codable, Equatable, Sendable {
        public var id: UUID
        public var name: String
        public var songIDs: [String]
        public var createdAt: Date

        public init(id: UUID, name: String, songIDs: [String], createdAt: Date) {
            self.id = id
            self.name = name
            self.songIDs = songIDs
            self.createdAt = createdAt
        }
    }

    public var isEmpty: Bool {
        settings.isEmpty && annotations.isEmpty && drawings.isEmpty && songs.isEmpty
            && favorites.isEmpty && setLists.isEmpty
    }

    /// Resumen para confirmar antes de importar.
    public var summary: String {
        var parts: [String] = []
        func add(_ n: Int, _ one: String, _ many: String) {
            if n > 0 { parts.append("\(n) \(n == 1 ? one : many)") }
        }
        add(annotations.count, "anotación", "anotaciones")
        add(drawings.count, "dibujo", "dibujos")
        add(songs.count, "canción editada o propia", "canciones editadas o propias")
        add(favorites.count, "favorita", "favoritas")
        add(setLists.count, "lista", "listas")
        add(settings.count, "ajuste de canción", "ajustes de canciones")
        return parts.isEmpty ? "La copia está vacía." : parts.joined(separator: ", ")
    }

    public enum BackupError: LocalizedError {
        case newerVersion(Int)

        public var errorDescription: String? {
            switch self {
            case let .newerVersion(v):
                return "Esta copia (versión \(v)) es de una versión más nueva de la app. Actualiza la app para importarla."
            }
        }
    }

    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }

    public static func decode(_ data: Data) throws -> Backup {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let backup = try decoder.decode(Backup.self, from: data)
        guard backup.version <= currentVersion else { throw BackupError.newerVersion(backup.version) }
        return backup
    }
}

public extension Array where Element == String {
    /// Mueve elementos como `List.onMove` (índices de origen y destino de SwiftUI).
    func moving(from source: IndexSet, to destination: Int) -> [String] {
        let moving = source.map { self[$0] }
        var rest = enumerated().filter { !source.contains($0.offset) }.map(\.element)
        let removedBefore = source.filter { $0 < destination }.count
        rest.insert(contentsOf: moving, at: Swift.min(destination - removedBefore, rest.count))
        return rest
    }
}
