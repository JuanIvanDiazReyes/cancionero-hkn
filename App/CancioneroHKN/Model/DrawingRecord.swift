import Foundation
import SwiftData

/// Trazos a mano (PencilKit) de un bloque de la canción.
/// Se guardan por bloque para que el dibujo siga junto a su estrofa.
@Model
final class DrawingRecord {
    var songID: String
    var block: Int
    @Attribute(.externalStorage) var data: Data

    init(songID: String, block: Int, data: Data) {
        self.songID = songID
        self.block = block
        self.data = data
    }
}
