import CancioneroCore
import Foundation
import SwiftData

/// Una anotación del cuaderno pegada a una línea de la canción:
/// voz (quién canta), instrumento que entra o sale, icono musical o nota de texto.
@Model
final class AnnotationRecord {
    var id: UUID
    var songID: String
    var block: Int
    var line: Int
    /// `AnnotationKind` como texto.
    var kindRaw: String
    /// Voz, id del instrumento, id del icono o el texto de la nota.
    var value: String
    /// Solo instrumentos: `InstrumentCue` como texto.
    var detail: String?
    var createdAt: Date

    init(songID: String, anchor: LineAnchor, kind: AnnotationKind, value: String, detail: String? = nil) {
        self.id = UUID()
        self.songID = songID
        self.block = anchor.block
        self.line = anchor.line
        self.kindRaw = kind.rawValue
        self.value = value
        self.detail = detail
        self.createdAt = .now
    }

    var kind: AnnotationKind? { AnnotationKind(rawValue: kindRaw) }
    var anchor: LineAnchor { LineAnchor(block: block, line: line) }
}
