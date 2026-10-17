import CancioneroCore
import SwiftUI

/// Editar una línea: cambiar, mover, añadir o quitar acordes y corregir la letra.
/// Los acordes se ven en el tono elegido y se guardan en el tono original.
struct LineEditSheet: View {
    let original: SongLine
    /// Acordes de la canción, ya en el tono que se ve, para elegir rápido.
    let suggestions: [String]
    let display: (String) -> String
    let toOriginal: (String) -> String
    let onSave: (SongLine) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var line: SongLine
    @State private var text: String
    @State private var selected: Int?
    @State private var chordName = ""
    @AppStorage("fontSize") private var fontSize: Double = 18

    init(line: SongLine, suggestions: [String], display: @escaping (String) -> String,
         toOriginal: @escaping (String) -> String, onSave: @escaping (SongLine) -> Void) {
        self.original = line
        self.suggestions = suggestions
        self.display = display
        self.toOriginal = toOriginal
        self.onSave = onSave
        _line = State(initialValue: line)
        _text = State(initialValue: line.displayText)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    preview
                    if case .directive = line {
                        EmptyView()
                    } else {
                        chordsSection
                        if selected != nil { selectedChordSection }
                    }
                    textSection
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Editar línea")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        onSave(line)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(line == original)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    // MARK: Vista previa

    private var preview: some View {
        Group {
            switch line {
            case let .lyric(lyric, chords):
                ChordLyricLine(text: lyric,
                               chords: chords.map { PositionedChord(pos: $0.pos, chord: display($0.chord)) },
                               fontSize: min(fontSize, 24))
            case let .instrumental(_, chords, _):
                Text(chords.map(display).joined(separator: "   "))
                    .font(Theme.chordFont(min(fontSize, 24)))
                    .foregroundStyle(Theme.chord)
            case let .directive(t):
                Text(t).font(Theme.lyricFont(17).italic()).foregroundStyle(Theme.secondaryInk)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).strokeBorder(Theme.hairline))
    }

    // MARK: Acordes

    private var chordNames: [String] {
        switch line {
        case let .lyric(_, chords): return chords.map { display($0.chord) }
        case let .instrumental(_, chords, _): return chords.map(display)
        case .directive: return []
        }
    }

    private var chordsSection: some View {
        section("Acordes · toca uno para cambiarlo") {
            FlowLayout(lineSpacing: 8) {
                ForEach(Array(chordNames.enumerated()), id: \.offset) { index, name in
                    Button {
                        selected = selected == index ? nil : index
                        chordName = name
                    } label: {
                        VStack(spacing: 2) {
                            Text(name)
                                .font(.system(.headline, design: .rounded))
                            if case let .lyric(lyric, chords) = line {
                                Text(syllable(in: lyric, at: chords[index].pos))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(selected == index ? Theme.chord : Theme.chord.opacity(0.12),
                                    in: RoundedRectangle(cornerRadius: 10))
                        .foregroundStyle(selected == index ? Color.white : Theme.chord)
                    }
                    .buttonStyle(.plain)
                    .padding(.trailing, 8)
                }
                Menu {
                    addMenu
                } label: {
                    Label("Añadir", systemImage: "plus")
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 13)
                        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
                        .overlay(RoundedRectangle(cornerRadius: 10).strokeBorder(Theme.hairline))
                }
            }
        }
    }

    @ViewBuilder
    private var addMenu: some View {
        if case let .lyric(lyric, _) = line {
            let starts = wordStarts(lyric)
            Section("Acorde nuevo sobre…") {
                ForEach(Array(starts.prefix(20)), id: \.self) { pos in
                    Button(word(in: lyric, at: pos)) { add(at: pos) }
                }
                Button("Final de la línea") { add(at: lyric.count) }
            }
        } else {
            Button("Al final") { add(at: 0) }
        }
    }

    private func add(at pos: Int) {
        let name = suggestions.first ?? "C"
        line = line.addingChord(toOriginal(name), at: pos)
        // Selecciona el acorde nuevo para cambiarle el nombre.
        if case let .lyric(_, chords) = line {
            selected = chords.lastIndex { $0.pos == pos }
        } else {
            selected = line.chordCount - 1
        }
        chordName = name
    }

    private var selectedChordSection: some View {
        section("Acorde seleccionado") {
            VStack(alignment: .leading, spacing: 14) {
                HStack {
                    TextField("Acorde", text: $chordName)
                        .font(.system(.title3, design: .rounded).weight(.semibold))
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textFieldStyle(.roundedBorder)
                        .onSubmit(applyName)
                    Button("Cambiar", action: applyName)
                        .buttonStyle(.borderedProminent)
                        .disabled(chordName.trimmingCharacters(in: .whitespaces).isEmpty)
                }
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(suggestions, id: \.self) { name in
                            Button(name) {
                                chordName = name
                                applyName()
                            }
                            .font(.system(.subheadline, design: .rounded).weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 7)
                            .background(Theme.chord.opacity(0.10), in: Capsule())
                            .foregroundStyle(Theme.chord)
                            .buttonStyle(.plain)
                        }
                    }
                }
                HStack(spacing: 10) {
                    if case .lyric = line {
                        moveButton("arrow.left.to.line", "Palabra") { line = line.movingChordByWord(at: $0, forward: false) }
                        moveButton("chevron.left", "Letra") { line = line.movingChord(at: $0, by: -1) }
                        moveButton("chevron.right", "Letra") { line = line.movingChord(at: $0, by: 1) }
                        moveButton("arrow.right.to.line", "Palabra") { line = line.movingChordByWord(at: $0, forward: true) }
                    }
                    Spacer(minLength: 0)
                    Button(role: .destructive) {
                        if let selected { line = line.removingChord(at: selected) }
                        selected = nil
                    } label: {
                        Image(systemName: "trash")
                            .frame(width: 44, height: 44)
                            .background(Color.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 10))
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Quitar acorde")
                }
            }
            .padding(14)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
        }
    }

    /// Mueve el acorde seleccionado y lo sigue seleccionando aunque cambie de orden.
    private func moveButton(_ symbol: String, _ caption: String, move: @escaping (Int) -> Void) -> some View {
        Button {
            guard let index = selected, case let .lyric(_, before) = line else { return }
            move(index)
            guard case let .lyric(_, after) = line else { return }
            // El acorde movido es el que ya no coincide con ninguno de los otros.
            var others = before
            others.remove(at: index)
            for (i, chord) in after.enumerated() {
                if let j = others.firstIndex(of: chord) {
                    others.remove(at: j)
                } else {
                    selected = i
                    return
                }
            }
        } label: {
            VStack(spacing: 2) {
                Image(systemName: symbol).font(.headline)
                Text(caption).font(.caption2)
            }
            .frame(width: 58, height: 44)
            .background(Theme.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 10))
            .foregroundStyle(Theme.accent)
        }
        .buttonStyle(.plain)
    }

    private func applyName() {
        guard let selected else { return }
        line = line.replacingChord(at: selected, with: toOriginal(chordName))
    }

    // MARK: Letra

    private var textSection: some View {
        section(textTitle) {
            TextField("Texto", text: $text, axis: .vertical)
                .font(Theme.lyricFont(18))
                .lineLimit(1...4)
                .padding(12)
                .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.hairline))
                .onChange(of: text) {
                    line = line.replacingLyric(with: text.replacingOccurrences(of: "\n", with: " "))
                    selected = nil
                }
            if case .lyric = line {
                Text("Los acordes se quedan sobre sus palabras al corregir la letra.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var textTitle: String {
        switch line {
        case .lyric: return "Letra"
        case .instrumental: return "Texto de la línea de acordes"
        case .directive: return "Indicación"
        }
    }

    // MARK: Ayudas

    private func wordStarts(_ text: String) -> [Int] {
        var starts: [Int] = []
        var previous: Character = " "
        for (i, c) in text.enumerated() {
            if !c.isWhitespace && previous.isWhitespace { starts.append(i) }
            previous = c
        }
        return starts
    }

    private func word(in text: String, at pos: Int) -> String {
        String(text.dropFirst(pos).prefix { !$0.isWhitespace })
    }

    private func syllable(in text: String, at pos: Int) -> String {
        let s = String(text.dropFirst(pos).prefix { !$0.isWhitespace }.prefix(6))
        return s.isEmpty ? "fin" : s
    }

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title.uppercased())
                .font(.caption.weight(.bold))
                .tracking(0.8)
                .foregroundStyle(.secondary)
            content()
        }
    }
}
