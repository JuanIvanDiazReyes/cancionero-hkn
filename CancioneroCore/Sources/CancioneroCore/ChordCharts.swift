import Foundation

// MARK: - Acorde

/// Un acorde leído de su nombre: "D/F#" → raíz D, tipo mayor, bajo F#.
public struct ChordSymbol: Hashable, Sendable {
    /// Nombre tal como se escribe (sin el "*" de variante).
    public var name: String
    /// Semitono de la raíz (0 = C).
    public var root: Int
    /// Tipo normalizado: "", "m", "7", "m7", "maj7", "add9", "sus4"…
    public var quality: String
    /// Intervalos desde la raíz en semitonos, de grave a agudo (la novena es 14).
    public var intervals: [Int]
    /// Nota del bajo en los acordes con barra.
    public var bass: Int?
    /// Si el nombre usa bemoles (para nombrar las notas igual).
    public var usesFlats: Bool
    /// El nombre llevaba "*": una posición especial que el cancionero define aparte.
    public var isVariant: Bool

    public var accidentals: Accidentals { usesFlats ? .flats : .sharps }

    /// Notas del acorde (sin octava), incluido el bajo.
    public var pitchClasses: Set<Int> {
        var set = Set(intervals.map { (root + $0) % 12 })
        if let bass { set.insert(bass) }
        return set
    }

    public var hasThird: Bool { intervals.contains(3) || intervals.contains(4) }
    public var third: Int? {
        intervals.first { $0 == 3 || $0 == 4 }.map { (root + $0) % 12 }
    }

    /// Nombres de las notas del acorde en orden: raíz, tercera, quinta…
    public var noteNames: [String] {
        intervals.map { Note.name(root + $0, accidentals) }
    }

    /// "Menor séptima", "Mayor con novena"…
    public var qualityName: String {
        let base = ChordSymbol.qualities.first { $0.key == quality }?.title ?? quality
        guard let bass else { return base }
        return base + " con bajo en " + Note.name(bass, accidentals)
    }

    struct Quality {
        var spelling: String
        var key: String
        var intervals: [Int]
        var title: String
    }

    /// Tipos de acorde reconocidos. Para leer, se prueban de más largo a más corto.
    static let qualities: [Quality] = [
        Quality(spelling: "maj7", key: "maj7", intervals: [0, 4, 7, 11], title: "Séptima mayor"),
        Quality(spelling: "madd9", key: "madd9", intervals: [0, 3, 7, 14], title: "Menor con novena"),
        Quality(spelling: "m7b5", key: "m7b5", intervals: [0, 3, 6, 10], title: "Semidisminuido"),
        Quality(spelling: "(add9)", key: "add9", intervals: [0, 4, 7, 14], title: "Mayor con novena"),
        Quality(spelling: "7sus4", key: "7sus4", intervals: [0, 5, 7, 10], title: "Séptima suspendida"),
        Quality(spelling: "add9", key: "add9", intervals: [0, 4, 7, 14], title: "Mayor con novena"),
        Quality(spelling: "dim7", key: "dim7", intervals: [0, 3, 6, 9], title: "Disminuido séptima"),
        Quality(spelling: "sus2", key: "sus2", intervals: [0, 2, 7], title: "Suspendido de segunda"),
        Quality(spelling: "sus4", key: "sus4", intervals: [0, 5, 7], title: "Suspendido de cuarta"),
        Quality(spelling: "maj", key: "", intervals: [0, 4, 7], title: "Mayor"),
        Quality(spelling: "dim", key: "dim", intervals: [0, 3, 6], title: "Disminuido"),
        Quality(spelling: "aug", key: "aug", intervals: [0, 4, 8], title: "Aumentado"),
        Quality(spelling: "sus", key: "sus4", intervals: [0, 5, 7], title: "Suspendido de cuarta"),
        Quality(spelling: "Sus", key: "sus4", intervals: [0, 5, 7], title: "Suspendido de cuarta"),
        Quality(spelling: "m9", key: "m9", intervals: [0, 3, 7, 10, 14], title: "Menor con novena (m9)"),
        Quality(spelling: "m7", key: "m7", intervals: [0, 3, 7, 10], title: "Menor séptima"),
        Quality(spelling: "m6", key: "m6", intervals: [0, 3, 7, 9], title: "Menor sexta"),
        Quality(spelling: "m", key: "m", intervals: [0, 3, 7], title: "Menor"),
        Quality(spelling: "9", key: "9", intervals: [0, 4, 7, 10, 14], title: "Novena"),
        Quality(spelling: "7", key: "7", intervals: [0, 4, 7, 10], title: "Séptima"),
        Quality(spelling: "6", key: "6", intervals: [0, 4, 7, 9], title: "Sexta"),
        Quality(spelling: "", key: "", intervals: [0, 4, 7], title: "Mayor"),
    ]

    /// Lee un solo acorde ("F#m7", "D/F#", "Bm*"). Devuelve `nil` si sobra algo.
    public static func parse(_ text: String) -> ChordSymbol? {
        let chars = Array(cleaned(text))
        var i = 0
        guard let chord = scan(chars, &i), i == chars.count else { return nil }
        return chord
    }

    /// Parte lo que el cancionero escribe como un solo acorde en los acordes que lo forman:
    /// "GCD" → G, C, D; "A-E" → A, E; "Am…" → Am. Si no se entiende, devuelve una lista vacía.
    public static func split(_ text: String) -> [ChordSymbol] {
        var result: [ChordSymbol] = []
        for part in cleaned(text).split(whereSeparator: { $0 == "-" || $0 == " " || $0 == "," }) {
            let chars = Array(part)
            var i = 0
            while i < chars.count {
                guard let chord = scan(chars, &i) else { return [] }
                result.append(chord)
            }
        }
        return result
    }

    private static func cleaned(_ text: String) -> String {
        text.replacingOccurrences(of: "…", with: "")
            .replacingOccurrences(of: "...", with: "")
            .trimmingCharacters(in: .whitespaces)
    }

    /// Lee una nota ("C", "F#", "Bb") desde `i`.
    private static func scanNote(_ chars: [Character], _ i: inout Int) -> (Int, String)? {
        guard i < chars.count, let base = Note.naturals[chars[i]] else { return nil }
        var name = String(chars[i])
        var value = base
        i += 1
        if i < chars.count, chars[i] == "#" || chars[i] == "b" {
            name.append(chars[i])
            value += chars[i] == "#" ? 1 : 11
            i += 1
        }
        return (value % 12, name)
    }

    private static func scan(_ chars: [Character], _ i: inout Int) -> ChordSymbol? {
        let start = i
        guard let note = scanNote(chars, &i) else { return nil }
        let (root, rootName) = note
        let rest = String(chars[i...])
        let quality = qualities.first(where: { rest.hasPrefix($0.spelling) })!
        i += quality.spelling.count
        var isVariant = false
        if i < chars.count, chars[i] == "*" {
            isVariant = true
            i += 1
        }
        var bass: Int?
        var bassName = ""
        if i < chars.count, chars[i] == "/" {
            var j = i + 1
            if let note = scanNote(chars, &j) {
                bass = note.0
                bassName = note.1
                i = j
                // "C/Am" en el cancionero: el bajo es la nota, la "m" sobra.
                if i < chars.count, chars[i] == "m", !(i + 1 < chars.count && chars[i + 1] == "a") { i += 1 }
            }
        }
        let name = String(chars[start..<i]).replacingOccurrences(of: "*", with: "")
        return ChordSymbol(name: name, root: root, quality: quality.key, intervals: quality.intervals,
                           bass: bass == root ? nil : bass,
                           usesFlats: rootName.hasSuffix("b") || bassName.hasSuffix("b"),
                           isVariant: isVariant)
    }
}

// MARK: - Guitarra

/// Una posición de guitarra. Las cuerdas van de la 6ª (Mi grave) a la 1ª (Mi agudo).
public struct GuitarShape: Hashable, Sendable {
    public struct Barre: Hashable, Sendable {
        public var fret: Int
        /// Cuerdas que cubre, como índices de `frets` (0 = 6ª cuerda).
        public var from: Int
        public var to: Int
    }

    /// Traste de cada cuerda: 0 = al aire, `nil` = no se toca.
    public var frets: [Int?]
    /// Dedo de cada cuerda pisada (1 índice … 4 meñique).
    public var fingers: [Int?]
    public var barre: Barre?
    /// La viene escrita en la canción (no del diccionario).
    public var isCustom: Bool

    /// Afinación estándar en MIDI: E2 A2 D3 G3 B3 E4.
    public static let openStrings = [40, 45, 50, 55, 59, 64]

    public init(frets: [Int?], isCustom: Bool = false) {
        self.frets = frets
        self.isCustom = isCustom
        let (fingers, barre) = GuitarShape.fingering(frets)
        self.fingers = fingers
        self.barre = barre
    }

    /// Lee "x02010", "x 2 4 4 3 0" o "3 0 4 4 3 0".
    public init?(diagram: String, isCustom: Bool = true) {
        let trimmed = diagram.trimmingCharacters(in: .whitespaces)
        let tokens: [String] = trimmed.contains(" ")
            ? trimmed.split(separator: " ").map(String.init)
            : trimmed.map { String($0) }
        guard tokens.count == 6 else { return nil }
        var frets: [Int?] = []
        for token in tokens {
            if token.lowercased() == "x" { frets.append(nil) }
            else if let n = Int(token), (0...24).contains(n) { frets.append(n) }
            else { return nil }
        }
        self.init(frets: frets, isCustom: isCustom)
    }

    /// "x32010"; los trastes de dos cifras van entre paréntesis: "x(10)(12)(12)(12)(10)".
    public var diagram: String {
        frets.map { fret in fret.map { $0 < 10 ? String($0) : "(\($0))" } ?? "x" }.joined()
    }

    /// Notas que suenan (MIDI), de grave a agudo.
    public var midiNotes: [Int] {
        frets.enumerated().compactMap { index, fret in fret.map { GuitarShape.openStrings[index] + $0 } }
    }

    public var lowestPitchClass: Int? { midiNotes.first.map { $0 % 12 } }

    /// Primer traste que se dibuja: 1 si la posición cabe arriba del mástil.
    public var baseFret: Int {
        let fretted = frets.compactMap { $0 }.filter { $0 > 0 }
        guard let high = fretted.max(), let low = fretted.min() else { return 1 }
        return high <= 4 ? 1 : low
    }

    /// Cuántos trastes hay que dibujar (al menos 4).
    public var fretSpan: Int {
        let high = frets.compactMap { $0 }.max() ?? 0
        return max(4, high - baseFret + 1)
    }

    /// Reparte los dedos: cejilla con el índice cuando hace falta y el resto
    /// por traste, de la cuerda grave a la aguda.
    static func fingering(_ frets: [Int?]) -> ([Int?], Barre?) {
        var fingers = [Int?](repeating: nil, count: frets.count)
        let fretted = frets.indices.filter { (frets[$0] ?? 0) > 0 }
        guard let low = fretted.map({ frets[$0]! }).min() else { return (fingers, nil) }

        var barre: Barre?
        let atLow = fretted.filter { frets[$0] == low }
        if atLow.count >= 2, let first = atLow.first {
            let covered = (first..<frets.count).allSatisfy { (frets[$0] ?? -1) >= low }
            let others = fretted.count - atLow.count
            // Media cejilla: el índice pisa las cuerdas agudas seguidas (Dm7 xx0211, F/A x03211).
            let topRun = atLow == Array(first..<frets.count) && (fretted.count > atLow.count || atLow.count >= 4)
            let needed = fretted.count > 4 || topRun
            if covered && needed && others <= 3 {
                barre = Barre(fret: low, from: first, to: frets.count - 1)
            }
        }

        var rest = fretted
        var previous = 0
        if barre != nil {
            for index in atLow { fingers[index] = 1 }
            rest = fretted.filter { frets[$0] != low }
            previous = 1
        }
        rest.sort { (frets[$0]!, $0) < (frets[$1]!, $1) }
        for (n, index) in rest.enumerated() {
            let byFret = frets[index]! - low + 1
            let room = 4 - (rest.count - 1 - n)
            let finger = min(max(previous + 1, min(byFret, room)), 4)
            fingers[index] = finger
            previous = finger
        }
        return (fingers, barre)
    }

    /// Comprueba que la posición suena bien para el acorde: solo notas del acorde,
    /// con la raíz y la tercera, y el bajo correcto.
    public func plays(_ chord: ChordSymbol) -> Bool {
        let notes = midiNotes.map { $0 % 12 }
        guard notes.count >= 3, Set(notes).isSubset(of: chord.pitchClasses) else { return false }
        guard notes.contains(chord.root) else { return false }
        if let third = chord.third, !notes.contains(third) { return false }
        return lowestPitchClass == (chord.bass ?? chord.root)
    }
}

public enum GuitarChords {
    /// Posiciones abiertas de uso común, escritas a mano. (raíz, tipo, trastes)
    static let openShapes: [(String, String, String)] = [
        ("C", "", "x32010"), ("C", "7", "x32310"), ("C", "maj7", "x32000"), ("C", "add9", "x32033"),
        ("C", "sus2", "x30013"), ("C", "sus4", "x33011"), ("C", "6", "x32210"),
        ("D", "", "xx0232"), ("D", "m", "xx0231"), ("D", "7", "xx0212"), ("D", "m7", "xx0211"),
        ("D", "maj7", "xx0222"), ("D", "sus2", "xx0230"), ("D", "sus4", "xx0233"), ("D", "6", "xx0202"),
        ("E", "", "022100"), ("E", "m", "022000"), ("E", "7", "020100"), ("E", "m7", "020000"),
        ("E", "maj7", "021100"), ("E", "sus4", "022200"), ("E", "add9", "024100"), ("E", "madd9", "024000"),
        ("E", "6", "022120"), ("E", "9", "020102"), ("E", "m9", "022032"),
        ("F", "maj7", "xx3210"), ("F", "add9", "xx3213"), ("F", "sus2", "xx3011"),
        ("G", "", "320003"), ("G", "7", "320001"), ("G", "maj7", "320002"), ("G", "6", "320000"),
        ("G", "sus4", "330013"), ("G", "sus2", "300033"), ("G", "add9", "320203"),
        ("A", "", "x02220"), ("A", "m", "x02210"), ("A", "7", "x02020"), ("A", "m7", "x02010"),
        ("A", "maj7", "x02120"), ("A", "sus2", "x02200"), ("A", "sus4", "x02230"), ("A", "add9", "x02420"),
        ("A", "madd9", "x02410"), ("A", "6", "x02222"), ("A", "7sus4", "x02030"), ("A", "dim7", "x01212"),
        ("B", "7", "x21202"), ("B", "m7", "x20202"),
    ]

    /// Formas móviles con cejilla, relativas al traste de la raíz.
    /// Forma de Mi: raíz en la 6ª cuerda.
    static let eShapes: [String: [Int?]] = [
        "": [0, 2, 2, 1, 0, 0],
        "m": [0, 2, 2, 0, 0, 0],
        "7": [0, 2, 0, 1, 0, 0],
        "m7": [0, 2, 0, 0, 0, 0],
        "maj7": [0, nil, 1, 1, 0, nil],
        "sus4": [0, 2, 2, 2, 0, 0],
        "7sus4": [0, 2, 0, 2, 0, 0],
        "6": [0, nil, -1, 1, 0, nil],
        "dim7": [0, nil, -1, 0, -1, nil],
        "m7b5": [0, nil, 0, 0, -1, nil],
    ]

    /// Forma de La: raíz en la 5ª cuerda.
    static let aShapes: [String: [Int?]] = [
        "": [nil, 0, 2, 2, 2, 0],
        "m": [nil, 0, 2, 2, 1, 0],
        "7": [nil, 0, 2, 0, 2, 0],
        "m7": [nil, 0, 2, 0, 1, 0],
        "maj7": [nil, 0, 2, 1, 2, 0],
        "sus2": [nil, 0, 2, 2, 0, 0],
        "sus4": [nil, 0, 2, 2, 3, 0],
        "7sus4": [nil, 0, 2, 0, 3, 0],
        "add9": [nil, 0, 2, 4, 2, 0],
        "madd9": [nil, 0, 2, 4, 1, 0],
        "6": [nil, 0, -1, -1, -2, nil],
        "m6": [nil, 0, 2, -1, 1, 0],
        "9": [nil, 0, -1, 0, 0, nil],
        "m9": [nil, 0, -2, 0, 0, nil],
        "dim": [nil, 0, 1, 2, 1, nil],
        "dim7": [nil, 0, 1, -1, 1, nil],
        "m7b5": [nil, 0, 1, 0, 1, nil],
        "aug": [nil, 0, -1, -2, -2, nil],
    ]

    /// Posiciones para un acorde, de la más fácil a la más difícil (como mucho `limit`).
    /// `custom` es el diagrama que trae la canción para ese acorde, si lo hay.
    public static func shapes(for chord: ChordSymbol, custom: String? = nil, limit: Int = 4) -> [GuitarShape] {
        var result: [GuitarShape] = []
        func add(_ shape: GuitarShape) {
            if !result.contains(where: { $0.frets == shape.frets }) { result.append(shape) }
        }
        if let custom, let shape = GuitarShape(diagram: custom) { add(shape) }

        var plain = chord
        plain.bass = nil
        var base: [GuitarShape] = []
        for (rootName, quality, diagram) in openShapes
        where Note.semitone(rootName) == chord.root && quality == chord.quality {
            if let shape = GuitarShape(diagram: diagram, isCustom: false) { base.append(shape) }
        }
        base += movableShapes(for: plain)

        if let bass = chord.bass {
            for shape in base {
                if let slashed = withBass(shape, bass: bass, chord: chord) { add(slashed) }
            }
            // Si no hay forma con ese bajo, al menos el acorde sin barra.
            if result.isEmpty, let first = base.first { add(first) }
        } else {
            for shape in base { add(shape) }
        }
        return Array(result.prefix(limit))
    }

    static func movableShapes(for chord: ChordSymbol) -> [GuitarShape] {
        var found: [(Int, GuitarShape)] = []
        for (string, table) in [(0, eShapes), (1, aShapes)] {
            guard let offsets = table[chord.quality] else { continue }
            let open = GuitarShape.openStrings[string] % 12
            let rootFret = ((chord.root - open) % 12 + 12) % 12
            for fret in [rootFret, rootFret + 12] {
                let frets = offsets.map { $0.map { $0 + fret } }
                let values = frets.compactMap { $0 }
                guard values.allSatisfy({ $0 >= 0 && $0 <= 15 }) else { continue }
                // Una forma al aire (traste 0) solo vale si es una de las posiciones abiertas de siempre.
                if fret == 0 && values.contains(where: { $0 > 4 }) { continue }
                let shape = GuitarShape(frets: frets)
                if shape.plays(chord) { found.append((fret, shape)) }
            }
        }
        return found.sorted { $0.0 < $1.0 }.map(\.1)
    }

    /// Pone `bass` como nota más grave, cambiando la 6ª, 5ª o 4ª cuerda.
    static func withBass(_ shape: GuitarShape, bass: Int, chord: ChordSymbol) -> GuitarShape? {
        if shape.lowestPitchClass == bass { return shape.plays(chord) ? shape : nil }
        for string in 0..<3 {
            let upper = shape.frets[(string + 1)...].compactMap { $0 }
            let fretted = upper.filter { $0 > 0 }
            let low = fretted.min() ?? 0
            let high = fretted.max() ?? 0
            let open = GuitarShape.openStrings[string] % 12
            let first = ((bass - open) % 12 + 12) % 12
            for fret in [first] {
                let reachable = fret == 0 || fretted.isEmpty || (abs(fret - low) <= 3 && abs(fret - high) <= 3)
                guard reachable else { continue }
                var frets = shape.frets
                for s in 0..<string { frets[s] = nil }
                frets[string] = fret
                let candidate = GuitarShape(frets: frets)
                let pressed = candidate.frets.compactMap { $0 }.filter { $0 > 0 }.count
                guard candidate.plays(chord), pressed <= 4 || candidate.barre != nil else { continue }
                return candidate
            }
        }
        return nil
    }
}

// MARK: - Piano

/// Teclas de un acorde en el piano, contadas en semitonos desde el primer Do del teclado.
public struct PianoVoicing: Hashable, Sendable {
    /// Teclas de la mano derecha (el acorde en estado fundamental).
    public var keys: [Int]
    /// Tecla del bajo en los acordes con barra (mano izquierda).
    public var bassKey: Int?
    /// Octavas que hay que dibujar (al menos 2).
    public var octaves: Int

    public var allKeys: [Int] { (bassKey.map { [$0] } ?? []) + keys }

    public init(chord: ChordSymbol) {
        var rootKey = chord.root
        if let bass = chord.bass {
            bassKey = bass
            if rootKey <= bass { rootKey += 12 }
        } else {
            bassKey = nil
        }
        keys = chord.intervals.sorted().map { rootKey + $0 }
        let highest = (keys + (bassKey.map { [$0] } ?? [])).max() ?? 0
        octaves = max(2, highest / 12 + 1)
    }

    /// Tecla negra (sostenido o bemol).
    public static func isBlack(_ key: Int) -> Bool {
        [1, 3, 6, 8, 10].contains(((key % 12) + 12) % 12)
    }
}
