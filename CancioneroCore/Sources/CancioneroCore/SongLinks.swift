import Foundation

/// De dónde es un link guardado en una canción.
public enum LinkKind: String, Codable, CaseIterable, Sendable {
    case spotify, youtube, drive, appleMusic, other

    /// Reconoce el servicio por la dirección.
    public static func detect(_ url: URL) -> LinkKind {
        if url.scheme?.lowercased() == "spotify" { return .spotify }
        let host = (url.host ?? "").lowercased()
        func on(_ domain: String) -> Bool { host == domain || host.hasSuffix("." + domain) }
        if on("spotify.com") || on("spotify.link") { return .spotify }
        if on("youtube.com") || on("youtu.be") || on("youtube-nocookie.com") { return .youtube }
        if on("drive.google.com") || on("docs.google.com") { return .drive }
        if on("music.apple.com") { return .appleMusic }
        return .other
    }

    /// Nombre por defecto si el usuario no le pone uno.
    public var defaultTitle: String {
        switch self {
        case .spotify: return "Spotify"
        case .youtube: return "YouTube"
        case .drive: return "Drive"
        case .appleMusic: return "Apple Music"
        case .other: return "Link"
        }
    }
}

public enum SongLinks {
    /// Saca el link de lo que se pegó. Spotify y YouTube a veces comparten
    /// "Escucha … en Spotify: https://…"; también acepta "youtu.be/…" sin https.
    public static func url(from text: String) -> URL? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let detector = try? NSDataDetector(types: NSTextCheckingResult.CheckingType.link.rawValue) {
            let range = NSRange(trimmed.startIndex..., in: trimmed)
            for match in detector.matches(in: trimmed, range: range) {
                if let url = match.url, let scheme = url.scheme?.lowercased(),
                   ["http", "https", "spotify"].contains(scheme) {
                    return url
                }
            }
        }
        if trimmed.lowercased().hasPrefix("spotify:"), let url = URL(string: trimmed) { return url }
        guard !trimmed.contains(" "), trimmed.contains("."),
              let url = URL(string: "https://" + trimmed), url.host != nil else { return nil }
        return url
    }
}
