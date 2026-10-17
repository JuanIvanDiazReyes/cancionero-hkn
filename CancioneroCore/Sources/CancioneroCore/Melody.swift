import Foundation

/// Figura rítmica de una nota.
public enum NoteValue: Int, CaseIterable, Codable, Sendable {
    case whole = 1, half = 2, quarter = 4, eighth = 8, sixteenth = 16

    public var name: String {
        switch self {
        case .whole: return "Redonda"
        case .half: return "Blanca"
        case .quarter: return "Negra"
        case .eighth: return "Corchea"
        case .sixteenth: return "Semicorchea"
        }
    }
}

/// Una nota de melodía (o un silencio si `pitch` es nil).
public struct MelodyNote: Hashable, Sendable {
    /// Nota MIDI: 60 = Do central (Do4).
    public var pitch: Int?
    public var value: NoteValue
    public var dotted: Bool
    /// Alteración escrita (para dibujar ♯ o ♭).
    public var accidental: Int

    public init(pitch: Int?, value: NoteValue = .quarter, dotted: Bool = false, accidental: Int = 0) {
        self.pitch = pitch
        self.value = value
        self.dotted = dotted
        self.accidental = accidental
    }

    public var isRest: Bool { pitch == nil }

    /// Posición en el pentagrama de clave de sol: 0 = primera línea (Mi4),
    /// cada paso es una línea o un espacio.
    public var staffStep: Int? {
        guard let pitch else { return nil }
        let natural = pitch - accidental
        let octave = natural / 12 - 1
        guard let degree = Melody.naturalSemitones.firstIndex(of: natural % 12) else { return nil }
        return (octave - 4) * 7 + degree - 2
    }
}

/// Elementos de una melodía escrita: notas y barras de compás.
public enum MelodyItem: Hashable, Sendable {
    case note(MelodyNote)
    case bar
}

/// Melodías escritas como texto: `Do Re Mi:8 Mi:8 Fa:2 | Sol:4. - La5`.
///
/// - Nota: `Do Re Mi Fa Sol La Si` o `C D E F G A B`, con `#` o `b` opcional.
/// - Octava opcional (Do central = `Do4`, la de por defecto).
/// - Duración opcional tras `:` — 1 redonda, 2 blanca, 4 negra (por defecto), 8 corchea, 16 semicorchea;
///   un punto al final la hace con puntillo.
/// - `-` es un silencio y `|` una barra de compás.
public enum Melody {
    static let naturalSemitones = [0, 2, 4, 5, 7, 9, 11]
    private static let solfege = ["do", "re", "mi", "fa", "sol", "la", "si"]
    private static let letters = ["c", "d", "e", "f", "g", "a", "b"]

    public static func parse(_ text: String) -> [MelodyItem] {
        text.split(whereSeparator: { $0 == " " || $0 == "," || $0 == "\n" }).compactMap { item(String($0)) }
    }

    /// Ninguna palabra quedó sin entender.
    public static func isValid(_ text: String) -> Bool {
        let words = text.split(whereSeparator: { $0 == " " || $0 == "," || $0 == "\n" })
        return !words.isEmpty && words.allSatisfy { item(String($0)) != nil }
    }

    static func item(_ word: String) -> MelodyItem? {
        if word == "|" { return .bar }
        var rest = Substring(word)
        var value = NoteValue.quarter
        var dotted = false
        if rest.hasSuffix(".") {
            dotted = true
            rest = rest.dropLast()
        }
        if let colon = rest.firstIndex(of: ":") {
            guard let n = Int(rest[rest.index(after: colon)...]), let v = NoteValue(rawValue: n) else { return nil }
            value = v
            rest = rest[..<colon]
        }
        if rest == "-" { return .note(MelodyNote(pitch: nil, value: value, dotted: dotted)) }

        let lower = rest.lowercased()
        var degree: Int?
        var nameLength = 0
        for (i, name) in solfege.enumerated() where lower.hasPrefix(name) {
            degree = i
            nameLength = name.count
            break
        }
        if degree == nil, let first = lower.first, let i = letters.firstIndex(of: String(first)) {
            degree = i
            nameLength = 1
        }
        guard let degree else { return nil }
        rest = rest.dropFirst(nameLength)

        var accidental = 0
        if rest.first == "#" || rest.first == "♯" {
            accidental = 1
            rest = rest.dropFirst()
        } else if rest.first == "b" || rest.first == "♭" {
            accidental = -1
            rest = rest.dropFirst()
        }
        var octave = 4
        if !rest.isEmpty {
            guard let o = Int(rest), (1...7).contains(o) else { return nil }
            octave = o
        }
        let pitch = (octave + 1) * 12 + naturalSemitones[degree] + accidental
        return .note(MelodyNote(pitch: pitch, value: value, dotted: dotted, accidental: accidental))
    }

    /// Nombre de la nota en solfeo (`Do#4`) o en letras (`C#4`).
    public static func name(of note: MelodyNote, solfege useSolfege: Bool = true) -> String {
        guard let pitch = note.pitch else { return "-" }
        let natural = pitch - note.accidental
        guard let degree = naturalSemitones.firstIndex(of: ((natural % 12) + 12) % 12) else { return "?" }
        let base = useSolfege ? solfege[degree].capitalized : letters[degree].uppercased()
        let acc = note.accidental > 0 ? "#" : note.accidental < 0 ? "b" : ""
        return "\(base)\(acc)\(natural / 12 - 1)"
    }
}
