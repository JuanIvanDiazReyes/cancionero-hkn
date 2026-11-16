import CancioneroCore
import Foundation
import SwiftData

/// Un link (Spotify, YouTube, Drive…) guardado en una canción.
@Model
final class SongLinkRecord {
    @Attribute(.unique) var id: UUID
    var songID: String
    var url: String
    var title: String
    var createdAt: Date

    init(id: UUID = UUID(), songID: String, url: String, title: String, createdAt: Date = .now) {
        self.id = id
        self.songID = songID
        self.url = url
        self.title = title
        self.createdAt = createdAt
    }

    var link: URL? { URL(string: url) }
    var kind: LinkKind { link.map(LinkKind.detect) ?? .other }
}
