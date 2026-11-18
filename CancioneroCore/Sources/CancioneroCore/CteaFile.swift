import Foundation

/// Archivo `.ctea`: un cancionero completo que se importa y exporta desde la app.
///
/// Por dentro es JSON. La app no trae canciones: todo llega en uno de estos archivos.
/// - `songs`: el cancionero base (p. ej. las 126 canciones de Hakuna).
/// - `notebook.songs`: canciones editadas por el usuario (mismo `id` que la base) y canciones propias.
/// - El resto de `notebook` (anotaciones, dibujos, tonos, favoritas, listas, links) solo viene
///   cuando se exporta «Todo».
public struct CteaFile: Codable, Equatable, Sendable {
    public static let formatName = "ctea"
    public static let currentVersion = 1
    public static let fileExtension = "ctea"

    public var format: String
    public var version: Int
    public var name: String
    public var exportedAt: Date
    public var songs: [Song]
    public var notebook: Backup

    public init(name: String, exportedAt: Date = Date(), songs: [Song], notebook: Backup = Backup()) {
        self.format = CteaFile.formatName
        self.version = CteaFile.currentVersion
        self.name = name
        self.exportedAt = exportedAt
        self.songs = songs
        self.notebook = notebook
    }

    enum CodingKeys: String, CodingKey {
        case format, version, name, exportedAt, songs, notebook
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        format = try c.decode(String.self, forKey: .format)
        version = try c.decode(Int.self, forKey: .version)
        name = try c.decodeIfPresent(String.self, forKey: .name) ?? "Cancionero"
        exportedAt = try c.decodeIfPresent(Date.self, forKey: .exportedAt) ?? Date(timeIntervalSince1970: 0)
        songs = try c.decodeIfPresent([Song].self, forKey: .songs) ?? []
        notebook = try c.decodeIfPresent(Backup.self, forKey: .notebook) ?? Backup()
    }

    // MARK: Qué trae

    /// Ediciones del usuario y canciones propias.
    public var editedSongs: [Backup.EditedSong] { notebook.songs }

    /// Anotaciones, dibujos, ajustes, favoritas, listas o links.
    public var hasNotebookData: Bool {
        var rest = notebook
        rest.songs = []
        return !rest.isEmpty
    }

    public var isEmpty: Bool { songs.isEmpty && notebook.isEmpty }

    /// Resumen para confirmar antes de importar.
    public var summary: String {
        var parts: [String] = []
        if !songs.isEmpty { parts.append("\(songs.count) \(songs.count == 1 ? "canción" : "canciones")") }
        if !notebook.isEmpty { parts.append(notebook.summary) }
        return parts.isEmpty ? "El archivo está vacío." : parts.joined(separator: ", ")
    }

    // MARK: Leer y escribir

    public enum FileError: LocalizedError, Equatable {
        case newerVersion(Int)
        case unknownFormat

        public var errorDescription: String? {
            switch self {
            case let .newerVersion(v):
                return "Este archivo (versión \(v)) es de una versión más nueva de CTEA. Actualiza la app para importarlo."
            case .unknownFormat:
                return "Ese archivo no es un cancionero de CTEA."
            }
        }
    }

    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys, .withoutEscapingSlashes]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(self)
    }

    /// Lee un `.ctea`, una copia de seguridad anterior (`.json` de Ajustes) o un `songbook.json`.
    public static func read(_ data: Data) throws -> CteaFile {
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            throw FileError.unknownFormat
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        if object["format"] as? String == formatName {
            if let v = object["version"] as? Int, v > currentVersion { throw FileError.newerVersion(v) }
            do { return try decoder.decode(CteaFile.self, from: data) } catch { throw FileError.unknownFormat }
        }
        if object["annotations"] != nil, object["exportedAt"] != nil {
            // Copia de seguridad de antes de los archivos .ctea: no trae cancionero base.
            let backup: Backup
            do { backup = try Backup.decode(data) } catch let e as Backup.BackupError {
                throw e
            } catch { throw FileError.unknownFormat }
            return CteaFile(name: "Copia de seguridad", exportedAt: backup.exportedAt, songs: [], notebook: backup)
        }
        if object["songs"] != nil {
            do {
                return CteaFile(name: "Cancionero", songs: try Songbook.decode(from: data).songs)
            } catch { throw FileError.unknownFormat }
        }
        throw FileError.unknownFormat
    }

    // MARK: Importar

    /// «Reemplazar todo»: queda exactamente lo del archivo.
    /// Si el archivo no trae cancionero base (una copia de seguridad anterior), se conserva el actual.
    public func replacing(_ current: CteaFile) -> CteaFile {
        var result = self
        if songs.isEmpty {
            result.songs = current.songs
            result.name = current.name
        }
        return result
    }

    /// «Combinar»: las canciones del archivo reemplazan a las que tienen el mismo `id` y se agregan las nuevas.
    /// Las anotaciones, dibujos y ajustes del usuario se quedan; los del archivo solo se agregan
    /// en canciones donde el usuario no tiene. Favoritas, listas y links se suman.
    public func combined(into current: CteaFile) -> CteaFile {
        var result = current
        let incoming = notebook

        // Cancionero base.
        var base = Dictionary(current.songs.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
        for song in songs { base[song.id] = song }
        result.songs = base.values.sorted { ($0.number, $0.id) < ($1.number, $1.id) }

        // Ediciones y canciones propias.
        var edits = current.notebook.songs
        func usedCustomNumbers(excluding id: String) -> Set<Int> {
            Set(edits.filter { $0.isCustom && $0.song.id != id }.map(\.song.number))
        }
        for var edited in incoming.songs {
            if edited.isCustom, usedCustomNumbers(excluding: edited.song.id).contains(edited.song.number) {
                let used = usedCustomNumbers(excluding: edited.song.id)
                var n = Swift.max(Song.firstCustomNumber, edited.song.number)
                while used.contains(n) { n += 1 }
                edited.song.number = n
            }
            if let i = edits.firstIndex(where: { $0.song.id == edited.song.id }) {
                edits[i] = edited
            } else {
                edits.append(edited)
            }
        }
        result.notebook.songs = edits

        // Ajustes, anotaciones y dibujos: solo donde el usuario no tiene.
        let settingsIDs = Set(current.notebook.settings.map(\.songID))
        result.notebook.settings += incoming.settings.filter { !settingsIDs.contains($0.songID) }
        let annotatedIDs = Set(current.notebook.annotations.map(\.songID))
        result.notebook.annotations += incoming.annotations.filter { !annotatedIDs.contains($0.songID) }
        let drawnBlocks = Set(current.notebook.drawings.map { "\($0.songID)#\($0.block)" })
        result.notebook.drawings += incoming.drawings.filter { !drawnBlocks.contains("\($0.songID)#\($0.block)") }

        // Favoritas, listas y links se suman.
        let favorites = Set(current.notebook.favorites)
        result.notebook.favorites += incoming.favorites.filter { !favorites.contains($0) }
        for list in incoming.setLists {
            if let i = result.notebook.setLists.firstIndex(where: { $0.id == list.id }) {
                result.notebook.setLists[i] = list
            } else {
                result.notebook.setLists.append(list)
            }
        }
        let links = Set(current.notebook.links.map { "\($0.songID)#\($0.url)" })
        result.notebook.links += incoming.links.filter { !links.contains("\($0.songID)#\($0.url)") }

        return result
    }
}

public extension Song {
    /// Las canciones creadas por el usuario se numeran a partir de 1001.
    static let firstCustomNumber = 1001
}
