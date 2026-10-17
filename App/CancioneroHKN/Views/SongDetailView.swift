import CancioneroCore
import SwiftData
import SwiftUI
import UIKit

/// Leer: solo la canción. Anotar: tocar una línea para marcarla. Dibujar: lápiz libre.
enum NotebookMode: String, CaseIterable, Identifiable {
    case read, annotate, draw

    var id: Self { self }
    var title: String {
        switch self {
        case .read: return "Leer"
        case .annotate: return "Anotar"
        case .draw: return "Dibujar"
        }
    }
}

/// Una canción como página de cuaderno: acordes con tono y cejilla ajustables,
/// anotaciones por línea y dibujo a mano. Todo se guarda en el teléfono.
struct SongDetailView: View {
    let song: Song

    @Environment(\.modelContext) private var context
    @Query private var records: [SongSettingsRecord]
    @Query private var annotationRecords: [AnnotationRecord]
    @Query private var drawingRecords: [DrawingRecord]
    @AppStorage("fontSize") private var fontSize: Double = 18
    @AppStorage("showChords") private var showChords = true
    @AppStorage("fingerDraws") private var fingerDraws = UIDevice.current.userInterfaceIdiom == .phone

    @State private var mode: NotebookMode = .read
    @State private var editingLine: LineAnchor?
    @State private var tool: DrawingTool = .pen(.black)
    @State private var canvasGeneration = 0

    init(song: Song) {
        self.song = song
        let id = song.id
        _records = Query(filter: #Predicate<SongSettingsRecord> { $0.songID == id })
        _annotationRecords = Query(filter: #Predicate<AnnotationRecord> { $0.songID == id })
        _drawingRecords = Query(filter: #Predicate<DrawingRecord> { $0.songID == id })
    }

    private var settings: ChordSettings { records.first?.settings ?? ChordSettings() }
    private var presentation: SongPresentation { SongPresentation(song: song, settings: settings) }
    private var annotationsByLine: [LineAnchor: [AnnotationRecord]] {
        Dictionary(grouping: annotationRecords, by: \.anchor)
    }

    var body: some View {
        let blocks = presentation.blocks
        let byLine = annotationsByLine
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                ForEach(Array(blocks.enumerated()), id: \.offset) { index, block in
                    BlockView(block: block, blockIndex: index, fontSize: fontSize, showChords: showChords,
                              annotations: byLine, isAnnotating: mode == .annotate,
                              onTapLine: { editingLine = $0 }, onDelete: delete)
                        .overlay {
                            BlockCanvas(initialData: drawingRecords.first { $0.block == index }?.data,
                                        isEditable: mode == .draw, tool: tool, fingerDraws: fingerDraws,
                                        onChange: { saveDrawing($0, block: index) })
                                .allowsHitTesting(mode == .draw)
                                .id("\(index)-\(canvasGeneration)")
                        }
                }
            }
            .padding(.leading, 30)
            .padding(.trailing, 16)
            .padding(.vertical, 16)
            .padding(.bottom, mode == .draw ? 80 : 0)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .scrollDisabled(mode == .draw && fingerDraws)
        .background(NotebookPaper())
        .overlay(alignment: .bottom) {
            if mode == .draw {
                DrawingPalette(tool: $tool, fingerDraws: $fingerDraws, onClearAll: clearDrawings)
                    .padding(.bottom, 12)
            }
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            Picker("Modo", selection: $mode) {
                ForEach(NotebookMode.allCases) { m in
                    Text(m.title).tag(m)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.bar)
        }
        .navigationTitle(song.title.capitalized(with: Locale(identifier: "es")))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
        .sheet(item: $editingLine) { anchor in
            AnnotationSheet(
                lineText: lineText(anchor, in: blocks),
                currentVoice: LineMarks(byLine[anchor] ?? []).voice?.voice,
                onVoice: { setVoice($0, at: anchor) },
                onInstrument: { add(.instrument, $0.id, detail: $1.rawValue, at: anchor) },
                onSticker: { add(.sticker, $0.id, at: anchor) },
                onNote: { add(.note, $0, at: anchor) }
            )
        }
    }

    // MARK: Anotaciones y dibujos

    private func lineText(_ anchor: LineAnchor, in blocks: [SongBlock]) -> String {
        guard blocks.indices.contains(anchor.block),
              blocks[anchor.block].lines.indices.contains(anchor.line) else { return "" }
        switch blocks[anchor.block].lines[anchor.line] {
        case let .lyric(text, _): return text
        case let .instrumental(_, _, text): return text
        case let .directive(text): return text
        }
    }

    private func add(_ kind: AnnotationKind, _ value: String, detail: String? = nil, at anchor: LineAnchor) {
        context.insert(AnnotationRecord(songID: song.id, anchor: anchor, kind: kind, value: value, detail: detail))
        try? context.save()
    }

    private func setVoice(_ voice: Voice?, at anchor: LineAnchor) {
        for r in annotationRecords where r.anchor == anchor && r.kind == .voice {
            context.delete(r)
        }
        if let voice {
            context.insert(AnnotationRecord(songID: song.id, anchor: anchor, kind: .voice, value: voice.rawValue))
        }
        try? context.save()
    }

    private func delete(_ record: AnnotationRecord) {
        context.delete(record)
        try? context.save()
    }

    private func saveDrawing(_ data: Data, block: Int) {
        if let existing = drawingRecords.first(where: { $0.block == block }) {
            existing.data = data
        } else {
            context.insert(DrawingRecord(songID: song.id, block: block, data: data))
        }
        try? context.save()
    }

    private func clearDrawings() {
        for r in drawingRecords { context.delete(r) }
        try? context.save()
        canvasGeneration += 1
    }

    // MARK: Cabecera

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(song.number). \(song.title)")
                .font(.title2.bold())
            Text(song.album)
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(spacing: 8) {
                if let key = presentation.soundingKey {
                    Badge(text: "Tono \(key.name(presentation.accidentals))")
                }
                Badge(text: presentation.capo == 0 ? "Sin cejilla" : "Cejilla \(presentation.capo)")
                if settings.transpose != 0 {
                    Badge(text: settings.transpose > 0 ? "+\(settings.transpose)" : "\(settings.transpose)",
                          tint: .orange)
                }
            }
            let voices = Set(annotationRecords.filter { $0.kind == .voice }.compactMap { Voice(rawValue: $0.value) })
            if !voices.isEmpty {
                HStack(spacing: 12) {
                    ForEach(Voice.allCases.filter { voices.contains($0) }, id: \.self) { voice in
                        Label(voice.title, systemImage: "circle.fill")
                            .font(.caption)
                            .foregroundStyle(Notebook.color(voice))
                    }
                }
            }
            if !song.chordDefinitions.isEmpty {
                Text(song.chordDefinitions.sorted { $0.key < $1.key }
                    .map { "\(presentation.chord($0.key)): \($0.value)" }.joined(separator: "   "))
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: Barra de herramientas

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItemGroup(placement: .primaryAction) {
            Button { change { $0.transpose -= 1 } } label: {
                Label("Bajar medio tono", systemImage: "minus.circle")
            }
            Menu {
                keyMenu
            } label: {
                Text(presentation.soundingKey?.name(presentation.accidentals) ?? "Tono")
                    .font(.headline)
            }
            Button { change { $0.transpose += 1 } } label: {
                Label("Subir medio tono", systemImage: "plus.circle")
            }
            Menu {
                optionsMenu
            } label: {
                Label("Opciones", systemImage: "slider.horizontal.3")
            }
        }
    }

    @ViewBuilder
    private var keyMenu: some View {
        if let original = presentation.originalShapesKey?.transposed(by: presentation.originalCapo) {
            Section("Elegir tono") {
                ForEach(-6..<6) { shift in
                    let key = original.transposed(by: shift)
                    Button {
                        change { $0.transpose = shift }
                    } label: {
                        if shift == settings.transpose {
                            Label(keyLabel(key, shift), systemImage: "checkmark")
                        } else {
                            Text(keyLabel(key, shift))
                        }
                    }
                }
            }
        }
    }

    private func keyLabel(_ key: Key, _ shift: Int) -> String {
        let name = key.name()
        switch shift {
        case 0: return "\(name) (original)"
        case let s where s > 0: return "\(name) (+\(s))"
        default: return "\(name) (\(shift))"
        }
    }

    @ViewBuilder
    private var optionsMenu: some View {
        Section("Cejilla") {
            Picker("Cejilla", selection: Binding(
                get: { presentation.capo },
                set: { capo in change { $0.capo = capo == presentation.originalCapo ? nil : capo } }
            )) {
                ForEach(0...9, id: \.self) { capo in
                    Text(capoLabel(capo)).tag(capo)
                }
            }
            if let suggested = presentation.suggestedCapo, suggested != presentation.capo {
                Button("Sugerir cejilla (\(capoLabel(suggested)))") {
                    change { $0.capo = suggested == presentation.originalCapo ? nil : suggested }
                }
            }
        }
        Section("Notación") {
            Picker("Notación", selection: Binding(
                get: { settings.accidentals },
                set: { acc in change { $0.accidentals = acc } }
            )) {
                Text("Automática").tag(Accidentals?.none)
                Text("Sostenidos (♯)").tag(Accidentals?.some(.sharps))
                Text("Bemoles (♭)").tag(Accidentals?.some(.flats))
            }
        }
        Section("Texto") {
            Button { fontSize = min(fontSize + 2, 40) } label: {
                Label("Letra más grande", systemImage: "textformat.size.larger")
            }
            Button { fontSize = max(fontSize - 2, 12) } label: {
                Label("Letra más pequeña", systemImage: "textformat.size.smaller")
            }
            Toggle("Mostrar acordes", isOn: $showChords)
        }
        if !settings.isDefault {
            Button("Volver al original", role: .destructive) {
                change { $0 = ChordSettings() }
            }
        }
    }

    private func capoLabel(_ capo: Int) -> String {
        let base = capo == 0 ? "Sin cejilla" : "Traste \(capo)"
        return capo == presentation.originalCapo ? "\(base) (original)" : base
    }

    /// Cambia los ajustes de esta canción y los guarda.
    private func change(_ update: (inout ChordSettings) -> Void) {
        let record: SongSettingsRecord
        if let existing = records.first {
            record = existing
        } else {
            record = SongSettingsRecord(songID: song.id)
            context.insert(record)
        }
        var s = record.settings
        update(&s)
        // Mantiene el tono entre -6 y +5 semitonos (una octava).
        s.transpose = ((s.transpose + 6) % 12 + 12) % 12 - 6
        record.settings = s
        try? context.save()
    }
}

private struct Badge: View {
    let text: String
    var tint: Color = .accentColor

    var body: some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(tint.opacity(0.15), in: Capsule())
            .foregroundStyle(tint)
    }
}
