import CancioneroCore
import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Pasa todo lo guardado en SwiftData a una `Backup` y de vuelta.
enum BackupService {
    static func makeBackup(from context: ModelContext) throws -> Backup {
        Backup(
            settings: try context.fetch(FetchDescriptor<SongSettingsRecord>()).map {
                .init(songID: $0.songID, transpose: $0.transpose, capo: $0.capo, accidentals: $0.accidentalsRaw,
                      bpm: $0.bpm, beatsPerBar: $0.beatsPerBar, beatUnit: $0.beatUnit, arrangement: $0.arrangement)
            },
            annotations: try context.fetch(FetchDescriptor<AnnotationRecord>()).map {
                .init(songID: $0.songID, block: $0.block, line: $0.line, kind: $0.kindRaw, value: $0.value,
                      detail: $0.detail, createdAt: $0.createdAt)
            },
            drawings: try context.fetch(FetchDescriptor<DrawingRecord>()).map {
                .init(songID: $0.songID, block: $0.block, data: $0.data)
            },
            songs: try context.fetch(FetchDescriptor<SongEditRecord>()).compactMap { record in
                record.song.map { .init(song: $0, isCustom: record.isCustom) }
            },
            favorites: try context.fetch(FetchDescriptor<FavoriteRecord>(sortBy: [SortDescriptor(\.createdAt)]))
                .map(\.songID),
            setLists: try context.fetch(FetchDescriptor<SetListRecord>(sortBy: [SortDescriptor(\.createdAt)])).map {
                .init(id: $0.id, name: $0.name, songIDs: $0.songIDs, createdAt: $0.createdAt)
            }
        )
    }

    /// Reemplaza todo lo guardado por el contenido de la copia.
    static func restore(_ backup: Backup, into context: ModelContext) throws {
        try context.delete(model: SongSettingsRecord.self)
        try context.delete(model: AnnotationRecord.self)
        try context.delete(model: DrawingRecord.self)
        try context.delete(model: SongEditRecord.self)
        try context.delete(model: FavoriteRecord.self)
        try context.delete(model: SetListRecord.self)

        for s in backup.settings {
            let r = SongSettingsRecord(songID: s.songID)
            r.transpose = s.transpose
            r.capo = s.capo
            r.accidentalsRaw = s.accidentals
            r.bpm = s.bpm
            r.beatsPerBar = s.beatsPerBar
            r.beatUnit = s.beatUnit
            r.arrangement = s.arrangement
            context.insert(r)
        }
        for a in backup.annotations {
            guard let kind = AnnotationKind(rawValue: a.kind) else { continue }
            let r = AnnotationRecord(songID: a.songID, anchor: LineAnchor(block: a.block, line: a.line),
                                     kind: kind, value: a.value, detail: a.detail)
            r.createdAt = a.createdAt
            context.insert(r)
        }
        for d in backup.drawings {
            context.insert(DrawingRecord(songID: d.songID, block: d.block, data: d.data))
        }
        for s in backup.songs {
            context.insert(SongEditRecord(song: s.song, isCustom: s.isCustom))
        }
        for (i, id) in backup.favorites.enumerated() {
            let r = FavoriteRecord(songID: id)
            r.createdAt = backup.exportedAt.addingTimeInterval(Double(i))
            context.insert(r)
        }
        for l in backup.setLists {
            context.insert(SetListRecord(id: l.id, name: l.name, songIDs: l.songIDs, createdAt: l.createdAt))
        }
        try context.save()
    }

    static func fileName(for date: Date = .now) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return "Cancionero HKN respaldo \(f.string(from: date))"
    }
}

/// El archivo .json que se guarda o comparte al exportar.
struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    var data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
