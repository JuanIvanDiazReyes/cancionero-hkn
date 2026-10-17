import Foundation

/// Texto editable de una canción, con los acordes dentro de la letra:
///
///     | INTRO: A E D F#m
///     [A]Al estar en la pre[C#m]sencia
///     > (ESTRIBILLO X2)
///
/// - `[A]` pone el acorde sobre la letra que sigue.
/// - Una línea que empieza con `| ` es solo de acordes (intro, solo…).
/// - Una línea que empieza con `> ` es una indicación.
/// - Una línea en blanco separa estrofas.
public enum SongText {
    public static func text(for blocks: [SongBlock]) -> String {
        blocks.map { block in
            block.lines.map(text(for:)).joined(separator: "\n")
        }.joined(separator: "\n\n")
    }

    public static func text(for line: SongLine) -> String {
        switch line {
        case let .instrumental(_, _, text): return "| " + text
        case let .directive(text): return "> " + text
        case let .lyric(text, chords):
            let chars = Array(text)
            var out = ""
            var last = 0
            for c in chords.sorted(by: { $0.pos < $1.pos }) {
                let pos = min(max(c.pos, last), chars.count)
                out += String(chars[last..<pos]) + "[\(c.chord)]"
                last = pos
            }
            out += String(chars[last...])
            // Una letra que empezaría como otro tipo de línea se escapa con "\".
            if out.hasPrefix("|") || out.hasPrefix(">") || out.hasPrefix("\\")
                || out.trimmingCharacters(in: .whitespaces).isEmpty {
                out = "\\" + out
            }
            return out
        }
    }

    public static func blocks(from text: String) -> [SongBlock] {
        var blocks: [SongBlock] = []
        var current: [SongLine] = []
        func close() {
            guard !current.isEmpty else { return }
            var label: String?
            if current.count == 1, case let .instrumental(l, _, _) = current[0] { label = l }
            blocks.append(SongBlock(label: label, lines: current))
            current = []
        }
        for raw in text.replacingOccurrences(of: "\r\n", with: "\n").components(separatedBy: "\n") {
            if raw.trimmingCharacters(in: .whitespaces).isEmpty {
                close()
            } else {
                current.append(line(from: raw))
            }
        }
        close()
        return blocks
    }

    public static func line(from raw: String) -> SongLine {
        if raw == "|" || raw.hasPrefix("| ") {
            return instrumental(String(raw.dropFirst(2)))
        }
        if raw.hasPrefix("> ") {
            return .directive(text: String(raw.dropFirst(2)))
        }
        let source = raw.hasPrefix("\\") ? String(raw.dropFirst()) : raw
        var text = ""
        var count = 0
        var chords: [PositionedChord] = []
        var rest = Substring(source)
        while let open = rest.firstIndex(of: "[") {
            let before = rest[..<open]
            text += before
            count += before.count
            let afterOpen = rest.index(after: open)
            if let close = rest[afterOpen...].firstIndex(of: "]"),
               ChordToken.isBracketChord(rest[afterOpen..<close]) {
                chords.append(PositionedChord(pos: count, chord: String(rest[afterOpen..<close])))
                rest = rest[rest.index(after: close)...]
            } else {
                text += "["
                count += 1
                rest = rest[afterOpen...]
            }
        }
        text += rest
        return .lyric(text: text, chords: chords)
    }

    /// `INTRO: A E D (x2)` → etiqueta INTRO y acordes A, E, D.
    static func instrumental(_ text: String) -> SongLine {
        var label: String?
        var rest = Substring(text)
        if let colon = text.firstIndex(of: ":") {
            let head = text[..<colon].trimmingCharacters(in: .whitespaces)
            if !head.isEmpty, !ChordToken.isChord(head) {
                label = head.uppercased()
                rest = text[text.index(after: colon)...]
            }
        }
        let chords = rest.split(separator: " ").map(String.init)
            .filter(ChordToken.isChord).map(ChordToken.normalized)
        return .instrumental(label: label, chords: chords, text: text)
    }
}

/// Reconoce acordes escritos a mano.
public enum ChordToken {
    private static let pattern = try! NSRegularExpression(
        pattern: "^[A-G](#|b)?(maj|min|dim|aug|sus|Sus|add|m|M|[0-9]|[()/+*°º#b…-]|[A-G](#|b)?)*$")

    /// `F#m`, `D/F#`, `Cadd9`, `DED-EDEDE`… pero no `Dios` ni `Ama`.
    public static func isChord<S: StringProtocol>(_ token: S) -> Bool {
        let s = String(token)
        return pattern.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)) != nil
    }

    /// Dentro de corchetes se acepta cualquier nombre que empiece por nota (p. ej. `Cd`).
    public static func isBracketChord<S: StringProtocol>(_ token: S) -> Bool {
        guard let first = token.first, "ABCDEFG".contains(first) else { return false }
        return !token.contains { $0 == " " || $0 == "[" || $0 == "]" }
    }

    /// Corrige `Fm#` → `F#m`, como hace el importador.
    public static func normalized(_ chord: String) -> String {
        chord.replacingOccurrences(of: "^([A-G])m([#b])", with: "$1$2m", options: .regularExpression)
    }
}
