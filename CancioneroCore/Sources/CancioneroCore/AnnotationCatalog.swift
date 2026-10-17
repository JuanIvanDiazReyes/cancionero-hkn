import Foundation

/// Quién canta una línea.
public enum Voice: String, CaseIterable, Codable, Sendable {
    case woman, man, together

    public var title: String {
        switch self {
        case .woman: return "Mujer"
        case .man: return "Hombre"
        case .together: return "Juntos"
        }
    }
}

/// Instrumento que entra o sale en una línea.
public struct Instrument: Identifiable, Hashable, Sendable {
    public let id: String
    public let name: String
    /// Nombre corto para la etiqueta del margen.
    public let short: String
    public let emoji: String

    public static let all: [Instrument] = [
        Instrument(id: "guitar", name: "Guitarra", short: "Guitarra", emoji: "🎸"),
        Instrument(id: "electric", name: "Guitarra eléctrica", short: "Eléctrica", emoji: "⚡️"),
        Instrument(id: "bass", name: "Bajo", short: "Bajo", emoji: "🎸"),
        Instrument(id: "piano", name: "Piano / teclado", short: "Piano", emoji: "🎹"),
        Instrument(id: "drums", name: "Batería", short: "Batería", emoji: "🥁"),
        Instrument(id: "percussion", name: "Cajón / percusión", short: "Percusión", emoji: "🪘"),
        Instrument(id: "strings", name: "Violín / cuerdas", short: "Cuerdas", emoji: "🎻"),
        Instrument(id: "winds", name: "Vientos", short: "Vientos", emoji: "🎺"),
        Instrument(id: "voice", name: "Voz", short: "Voz", emoji: "🎤"),
        Instrument(id: "claps", name: "Palmas", short: "Palmas", emoji: "👏"),
    ]

    public static func find(_ id: String) -> Instrument? { all.first { $0.id == id } }
}

/// Si el instrumento entra o sale en esa línea.
public enum InstrumentCue: String, CaseIterable, Codable, Sendable {
    case enters, exits

    public var title: String { self == .enters ? "Entra" : "Sale" }
}

/// Indicación musical que se pega a una línea: un símbolo de SF Symbols o un texto.
public struct Sticker: Identifiable, Hashable, Sendable {
    public enum Look: Hashable, Sendable {
        case symbol(String)
        case text(String)
    }

    public let id: String
    public let name: String
    public let look: Look

    public static let all: [Sticker] = [
        Sticker(id: "arrow", name: "Flecha", look: .symbol("arrow.right")),
        Sticker(id: "repeat", name: "Repetir", look: .symbol("repeat")),
        Sticker(id: "x2", name: "Dos veces", look: .text("x2")),
        Sticker(id: "x3", name: "Tres veces", look: .text("x3")),
        Sticker(id: "pause", name: "Pausa", look: .symbol("pause.fill")),
        Sticker(id: "stop", name: "Parar", look: .symbol("hand.raised.fill")),
        Sticker(id: "attention", name: "Atención", look: .symbol("exclamationmark.triangle.fill")),
        Sticker(id: "eye", name: "Ojo", look: .symbol("eye.fill")),
        Sticker(id: "star", name: "Importante", look: .symbol("star.fill")),
        Sticker(id: "p", name: "Piano (suave)", look: .text("p")),
        Sticker(id: "mf", name: "Mezzoforte", look: .text("mf")),
        Sticker(id: "f", name: "Forte (fuerte)", look: .text("f")),
        Sticker(id: "cresc", name: "Crescendo", look: .text("cresc.")),
        Sticker(id: "dim", name: "Decrescendo", look: .text("dim.")),
        Sticker(id: "rit", name: "Ritardando", look: .text("rit.")),
        Sticker(id: "fermata", name: "Calderón (sostener)", look: .text("𝄐")),
        Sticker(id: "solo", name: "Solo instrumental", look: .text("Solo")),
        Sticker(id: "all", name: "Todos", look: .text("Todos")),
    ]

    public static func find(_ id: String) -> Sticker? { all.first { $0.id == id } }
}

/// Qué tipo de anotación es (se guarda como texto en la base de datos).
public enum AnnotationKind: String, Codable, Sendable {
    case voice, instrument, sticker, note, melody
}

/// Línea de una canción: bloque y posición dentro del bloque.
public struct LineAnchor: Hashable, Codable, Sendable, Identifiable {
    public var id: Self { self }
    public var block: Int
    public var line: Int

    public init(block: Int, line: Int) {
        self.block = block
        self.line = line
    }
}
