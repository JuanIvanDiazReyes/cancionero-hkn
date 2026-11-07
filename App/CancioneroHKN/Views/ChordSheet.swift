import CancioneroCore
import SwiftUI

/// Instrumento con el que se dibujan los acordes.
enum ChordInstrument: String, CaseIterable, Identifiable {
    case guitar, piano

    static let storageKey = "chordInstrument"
    var id: Self { self }

    var name: String {
        switch self {
        case .guitar: return "Guitarra"
        case .piano: return "Piano"
        }
    }

    var systemImage: String {
        switch self {
        case .guitar: return "guitars"
        case .piano: return "pianokeys"
        }
    }
}

/// Acción al tocar un acorde en la letra (solo en modo Leer).
private struct ChordTapKey: EnvironmentKey {
    static let defaultValue: ((String) -> Void)? = nil
}

extension EnvironmentValues {
    var onTapChord: ((String) -> Void)? {
        get { self[ChordTapKey.self] }
        set { self[ChordTapKey.self] = newValue }
    }
}

extension View {
    /// Hace tocable un acorde solo cuando hay acción (en Anotar o Editar el toque es de la línea).
    @ViewBuilder
    func chordTap(_ chord: String?, _ action: ((String) -> Void)?) -> some View {
        if let chord, let action, !chord.trimmingCharacters(in: .whitespaces).isEmpty {
            self.contentShape(Rectangle())
                .onTapGesture { action(chord) }
                .accessibilityAddTraits(.isButton)
        } else {
            self
        }
    }
}

/// Acorde que se va a mostrar.
struct ChordRequest: Identifiable {
    let id = UUID()
    let name: String
}

/// Hoja con la digitación de un acorde en guitarra o piano.
struct ChordSheet: View {
    /// El acorde tal como se ve en la letra ("D/F#", "GCD"…).
    let name: String
    /// Diagramas propios de la canción (solo si se ve en el tono original).
    var definitions: [String: String] = [:]
    /// Cejilla: en el piano se muestra lo que suena.
    var capo: Int = 0
    var soundingAccidentals: Accidentals = .sharps

    @Environment(\.dismiss) private var dismiss
    @AppStorage(ChordInstrument.storageKey) private var instrument: ChordInstrument = .guitar
    @State private var selected = 0
    @State private var shapeIndex = 0

    struct Entry: Identifiable, Hashable {
        let id: Int
        let name: String
        let symbol: ChordSymbol?
        let custom: String?
    }

    private var entries: [Entry] {
        let token = name.replacingOccurrences(of: "…", with: "").trimmingCharacters(in: .whitespaces)
        let chords = ChordSymbol.split(token)
        if chords.count <= 1 {
            return [Entry(id: 0, name: token, symbol: chords.first, custom: definitions[token] ?? definitions[name])]
        }
        var seen = Set<String>()
        return chords.filter { seen.insert($0.name).inserted }.enumerated().map { index, chord in
            Entry(id: index, name: chord.name, symbol: chord, custom: definitions[chord.name])
        }
    }

    var body: some View {
        let list = self.entries
        let entry = list[min(selected, list.count - 1)]
        NavigationStack {
            ScrollView {
                VStack(spacing: 18) {
                    if list.count > 1 { chordPicker(list) }
                    header(entry)
                    Picker("Instrumento", selection: $instrument) {
                        ForEach(ChordInstrument.allCases) { item in
                            Text(item.name).tag(item)
                        }
                    }
                    .pickerStyle(.segmented)
                    switch instrument {
                    case .guitar: guitar(entry)
                    case .piano: piano(entry)
                    }
                }
                .padding()
                .animation(.snappy, value: instrument)
                .animation(.snappy, value: selected)
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(list.count > 1 ? name : "Acorde")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Listo") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .onChange(of: selected) { shapeIndex = 0 }
    }

    // MARK: Cabecera

    private func chordPicker(_ entries: [Entry]) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(entries) { item in
                    Button { selected = item.id } label: {
                        Text(item.name)
                            .font(.system(.headline, design: .rounded).weight(.bold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .background(item.id == selected ? Theme.chord : Theme.chord.opacity(0.1), in: Capsule())
                            .foregroundStyle(item.id == selected ? Color.white : Theme.chord)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private func header(_ entry: Entry) -> some View {
        HStack(alignment: .center, spacing: 14) {
            Text(entry.name)
                .font(.system(size: 44, weight: .bold, design: .rounded))
                .foregroundStyle(Theme.chord)
                .minimumScaleFactor(0.5)
                .lineLimit(1)
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.symbol?.qualityName ?? "Posición del cancionero")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Theme.ink)
                if let symbol = entry.symbol {
                    Text(noteList(symbol))
                        .font(.footnote.monospaced())
                        .foregroundStyle(Theme.secondaryInk)
                }
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Theme.hairline))
    }

    private func noteList(_ symbol: ChordSymbol) -> String {
        var notes = symbol.noteNames
        if let bass = symbol.bass { notes.insert(Note.name(bass, symbol.accidentals), at: 0) }
        return notes.joined(separator: " · ")
    }

    // MARK: Guitarra

    @ViewBuilder
    private func guitar(_ entry: Entry) -> some View {
        let shapes: [GuitarShape] = {
            if let symbol = entry.symbol { return GuitarChords.shapes(for: symbol, custom: entry.custom) }
            return entry.custom.flatMap { GuitarShape(diagram: $0) }.map { [$0] } ?? []
        }()
        if shapes.isEmpty {
            unavailable("No conozco la digitación de «\(entry.name)».")
        } else {
            VStack(spacing: 10) {
                TabView(selection: $shapeIndex) {
                    ForEach(Array(shapes.enumerated()), id: \.offset) { index, shape in
                        VStack(spacing: 8) {
                            GuitarDiagram(shape: shape)
                                .frame(width: 220, height: 270)
                            Text(caption(shape))
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(shape.isCustom ? Theme.accent : Theme.secondaryInk)
                        }
                        .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                .frame(height: 310)
                if shapes.count > 1 {
                    HStack(spacing: 6) {
                        ForEach(shapes.indices, id: \.self) { index in
                            Circle()
                                .fill(index == shapeIndex ? Theme.chord : Theme.secondaryInk.opacity(0.3))
                                .frame(width: 7, height: 7)
                        }
                    }
                    Text("Desliza para ver otras posiciones")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Theme.hairline))
            if entry.symbol?.bass != nil, let first = shapes.first, first.lowestPitchClass != entry.symbol?.bass {
                Text("El bajo \(entry.name.split(separator: "/").last ?? "") lo hace otro instrumento o la mano izquierda.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func caption(_ shape: GuitarShape) -> String {
        if shape.isCustom { return "Posición del cancionero" }
        if shape.barre != nil { return "Con cejilla en el traste \(shape.barre!.fret)" }
        return shape.baseFret == 1 ? "Posición abierta" : "Desde el traste \(shape.baseFret)"
    }

    // MARK: Piano

    @ViewBuilder
    private func piano(_ entry: Entry) -> some View {
        if let symbol = entry.symbol {
            let sounding = capo == 0 ? symbol
                : ChordSymbol.parse(Transposer.transpose(symbol.name, by: capo, accidentals: soundingAccidentals)) ?? symbol
            VStack(alignment: .leading, spacing: 12) {
                if capo > 0 {
                    Label("Con cejilla \(capo), en el piano suena \(sounding.name).", systemImage: "info.circle")
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(Theme.accent)
                }
                PianoKeyboard(voicing: PianoVoicing(chord: sounding), accidentals: sounding.accidentals)
                    .frame(height: 150)
                HStack(spacing: 16) {
                    legend(Theme.chord, "Mano derecha")
                    if sounding.bass != nil { legend(Theme.accent, "Bajo (mano izquierda)") }
                }
                .font(.caption)
                .foregroundStyle(Theme.secondaryInk)
            }
            .padding(16)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 18))
            .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Theme.hairline))
        } else {
            unavailable("Este acorde solo tiene la posición de guitarra que trae el cancionero.")
        }
    }

    private func legend(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 14, height: 10)
            Text(text)
        }
    }

    private func unavailable(_ text: String) -> some View {
        Label(text, systemImage: "questionmark.circle")
            .font(.subheadline)
            .foregroundStyle(Theme.secondaryInk)
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 18))
    }
}

// MARK: - Diagrama de guitarra

/// Mástil de frente: cuerdas verticales (6ª a la izquierda), trastes horizontales.
struct GuitarDiagram: View {
    let shape: GuitarShape
    var color: Color = Theme.chord

    var body: some View {
        Canvas { ctx, size in
            let base = shape.baseFret
            let span = shape.fretSpan
            let top: CGFloat = 30, bottom: CGFloat = 24, left: CGFloat = 34, right: CGFloat = 16
            let sx = (size.width - left - right) / 5
            let fy = (size.height - top - bottom) / CGFloat(span)
            let radius = min(sx, fy) * 0.38
            let ink = Theme.ink
            let line = Theme.secondaryInk

            func x(_ string: Int) -> CGFloat { left + CGFloat(string) * sx }
            func y(_ fret: Int) -> CGFloat { top + (CGFloat(fret - base) + 0.5) * fy }

            // Trastes y cejuela.
            for i in 0...span {
                var p = Path()
                let yy = top + CGFloat(i) * fy
                p.move(to: CGPoint(x: x(0), y: yy))
                p.addLine(to: CGPoint(x: x(5), y: yy))
                let nut = i == 0 && base == 1
                ctx.stroke(p, with: .color(nut ? ink : line.opacity(0.55)), lineWidth: nut ? 5 : 1.2)
            }
            // Cuerdas: más gruesas las graves.
            for s in 0..<6 {
                var p = Path()
                p.move(to: CGPoint(x: x(s), y: top))
                p.addLine(to: CGPoint(x: x(s), y: top + CGFloat(span) * fy))
                ctx.stroke(p, with: .color(line.opacity(0.85)), lineWidth: 2.2 - CGFloat(s) * 0.25)
            }
            if base > 1 {
                ctx.draw(Text("\(base)").font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(line),
                         at: CGPoint(x: left - 18, y: y(base)))
            }
            // Al aire (○) o sin tocar (×).
            for (s, fret) in shape.frets.enumerated() {
                let point = CGPoint(x: x(s), y: top - 14)
                if fret == nil {
                    ctx.draw(Text("×").font(.system(size: 18, weight: .semibold)).foregroundStyle(line), at: point)
                } else if fret == 0 {
                    let r: CGFloat = 6
                    ctx.stroke(Path(ellipseIn: CGRect(x: point.x - r, y: point.y - r, width: 2 * r, height: 2 * r)),
                               with: .color(ink), lineWidth: 1.6)
                }
            }
            // Cejilla.
            if let barre = shape.barre {
                let rect = CGRect(x: x(barre.from) - radius, y: y(barre.fret) - radius,
                                  width: x(barre.to) - x(barre.from) + 2 * radius, height: 2 * radius)
                ctx.fill(Path(roundedRect: rect, cornerRadius: radius), with: .color(color))
                ctx.draw(Text("1").font(.system(size: radius * 1.1, weight: .bold, design: .rounded)).foregroundStyle(.white),
                         at: CGPoint(x: x(barre.from), y: y(barre.fret)))
            }
            // Dedos.
            for (s, fret) in shape.frets.enumerated() {
                guard let fret, fret > 0 else { continue }
                if let barre = shape.barre, barre.fret == fret, (barre.from...barre.to).contains(s) { continue }
                let c = CGPoint(x: x(s), y: y(fret))
                ctx.fill(Path(ellipseIn: CGRect(x: c.x - radius, y: c.y - radius, width: 2 * radius, height: 2 * radius)),
                         with: .color(color))
                if let finger = shape.fingers[s] {
                    ctx.draw(Text("\(finger)").font(.system(size: radius * 1.1, weight: .bold, design: .rounded))
                        .foregroundStyle(.white), at: c)
                }
            }
            // Nota de cada cuerda.
            for (s, fret) in shape.frets.enumerated() {
                guard let fret else { continue }
                let name = Note.name(GuitarShape.openStrings[s] + fret, .sharps)
                ctx.draw(Text(name).font(.system(size: 11, weight: .medium, design: .rounded)).foregroundStyle(line),
                         at: CGPoint(x: x(s), y: size.height - 10))
            }
        }
        .accessibilityElement()
        .accessibilityLabel(accessibilityText)
    }

    private var accessibilityText: String {
        let names = ["sexta", "quinta", "cuarta", "tercera", "segunda", "primera"]
        return shape.frets.enumerated().map { s, fret in
            switch fret {
            case nil: return "\(names[s]) cuerda sin tocar"
            case 0?: return "\(names[s]) al aire"
            case let f?: return "\(names[s]) traste \(f)"
            }
        }.joined(separator: ", ")
    }
}

// MARK: - Teclado de piano

struct PianoKeyboard: View {
    let voicing: PianoVoicing
    var accidentals: Accidentals = .sharps

    private static let whiteSemitones = [0, 2, 4, 5, 7, 9, 11]
    /// Teclas negras: semitono y tras qué tecla blanca (índice 0-6) va.
    private static let blackKeys = [(1, 0), (3, 1), (6, 3), (8, 4), (10, 5)]

    var body: some View {
        GeometryReader { geo in
            let whiteCount = voicing.octaves * 7
            let ww = geo.size.width / CGFloat(whiteCount)
            let bw = ww * 0.62
            let bh = geo.size.height * 0.6
            ZStack(alignment: .topLeading) {
                ForEach(0..<whiteCount, id: \.self) { i in
                    let key = (i / 7) * 12 + Self.whiteSemitones[i % 7]
                    let fill = color(for: key)
                    RoundedRectangle(cornerRadius: 5)
                        .fill(fill ?? Color.white)
                        .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Color.black.opacity(0.25), lineWidth: 1))
                        .overlay(alignment: .bottom) {
                            if fill != nil {
                                Text(Note.name(key, accidentals))
                                    .font(.system(size: min(ww * 0.42, 14), weight: .bold, design: .rounded))
                                    .foregroundStyle(.white)
                                    .padding(.bottom, 8)
                            } else if key % 12 == 0 {
                                Text("C\(key / 12 + 3)")
                                    .font(.system(size: min(ww * 0.32, 10), weight: .medium))
                                    .foregroundStyle(.black.opacity(0.35))
                                    .padding(.bottom, 6)
                            }
                        }
                        .frame(width: ww - 1.5, height: geo.size.height)
                        .offset(x: CGFloat(i) * ww)
                }
                ForEach(0..<voicing.octaves, id: \.self) { octave in
                    ForEach(0..<Self.blackKeys.count, id: \.self) { j in
                        let key = octave * 12 + Self.blackKeys[j].0
                        let after = Self.blackKeys[j].1
                        let fill = color(for: key)
                        RoundedRectangle(cornerRadius: 4)
                            .fill(fill ?? Color(white: 0.12))
                            .overlay(alignment: .bottom) {
                                if fill != nil {
                                    Text(Note.name(key, accidentals))
                                        .font(.system(size: min(bw * 0.4, 11), weight: .bold, design: .rounded))
                                        .foregroundStyle(.white)
                                        .minimumScaleFactor(0.6)
                                        .padding(.bottom, 6)
                                }
                            }
                            .frame(width: bw, height: bh)
                            .offset(x: CGFloat(octave * 7 + after + 1) * ww - bw / 2 - 0.75)
                    }
                }
            }
        }
        .accessibilityElement()
        .accessibilityLabel(voicing.allKeys.map { Note.name($0, accidentals) }.joined(separator: ", "))
    }

    private func color(for key: Int) -> Color? {
        if key == voicing.bassKey { return Theme.accent }
        if voicing.keys.contains(key) { return Theme.chord }
        return nil
    }
}
