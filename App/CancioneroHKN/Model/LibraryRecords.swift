import Foundation
import SwiftData

/// Una canción marcada como favorita.
@Model
final class FavoriteRecord {
    @Attribute(.unique) var songID: String
    var createdAt: Date

    init(songID: String) {
        self.songID = songID
        self.createdAt = .now
    }
}

/// Una lista de canciones en orden (p. ej. el repertorio de una misa o un ensayo).
@Model
final class SetListRecord {
    @Attribute(.unique) var id: UUID
    var name: String
    var songIDs: [String]
    var createdAt: Date

    init(id: UUID = UUID(), name: String, songIDs: [String] = [], createdAt: Date = .now) {
        self.id = id
        self.name = name
        self.songIDs = songIDs
        self.createdAt = createdAt
    }
}
