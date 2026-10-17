import CancioneroCore
import SwiftData
import SwiftUI
import UIKit

/// Leer: solo la canción. Anotar: tocar una línea para marcarla. Dibujar: lápiz libre.
/// Editar: tocar una línea para cambiar sus acordes o su letra.
enum NotebookMode: String, CaseIterable, Identifiable {
    case read, annotate, draw, edit

    var id: Self { self }
    var title: String {
        switch self {
        case .read: return "Leer"
        case .annotate: return "Anotar"
        case .draw: return "Dibujar"
        case .edit: return "Editar"
        }
    }
    var symbol: String {
        switch self {
        case .read: return "book"
        case .annotate: return "tag"
        case .draw: return "pencil.tip"
        case .edit: return "character.cursor.ibeam"
        }
    }
}

/// Una canción como página de cuaderno: acordes con tono y cejilla ajustables,
/// anotaciones por línea y dibujo a mano. Todo se guarda en el teléfono.
struct SongDetailView: View {
    let song: Song
    /// La lista (favoritas o una lista propia) desde la que se abrió, para ir a la anterior o la siguiente.
    var queue: SongQueue?
    /// Abre otra canción (p. ej. la copia recién duplicada).
    var onOpen: (String) -> Void = { _ in }
    /// La canción se eliminó.
    var onClose: () -> Void = {}

    @Environment(\.modelContext) private var context
    @Query private var records: [SongSettingsRecord]
    @Query private var annotationRecords: [AnnotationRecord]
    @Query private var drawingRecords: [DrawingRecord]
    @Query private var editRecords: [SongEditRecord]
    @Query private var favoriteRecords: [FavoriteRecord]
    @Query(sort: \SetListRecord.createdAt) private var setLists: [SetListRecord]
    @StateObject private var metronome = Metronome()
    @AppStorage("fontSize") private var fontSize: Double = 18
    @AppStorage("showChords") private var showChords = true
    @AppStorage("fingerDraws") private var fingerDraws = UIDevice.current.userInterfaceIdiom == .phone

    @State private var mode: NotebookMode = .read
    @State private var editingLine: LineAnchor?
    @State private var tool: DrawingTool = .pen(.black)
    @State private var canvasGeneration = 0
    @State private var pinchBase: Double?
    @State private var zoomHUD: Int?
    @State private var lineToEdit: LineAnchor?
    @State private var showTempo = false
    @State private var showEditor = false
    @State private var confirmDelete = false

    static let baseFontSize = 18.0

    init(song: Song, queue: SongQueue? = nil, onOpen: @escaping (String) -> Void = { _ in },
         onClose: @escaping () -> Void = {}) {
        self.song = song
        self.queue = queue
        self.onOpen = onOpen
        self.onClose = onClose
        let id = song.id
        _records = Query(filter: #Predicate<SongSettingsRecord> { $0.songID == id })
        _annotationRecords = Query(filter: #Predicate<AnnotationRecord> { $0.songID == id })
        _drawingRecords = Query(filter: #Predicate<DrawingRecord> { $0.songID == id })
        _editRecords = Query(filter: #Predicate<SongEditRecord> { $0.songID == id })
        _favoriteRecords = Query(filter: #Predicate<FavoriteRecord> { $0.songID == id })
    }

    private var editRecord: SongEditRecord? { editRecords.first }
    private var isCustom: Bool { editRecord?.isCustom == true }
    private var isEditedOriginal: Bool { editRecord != nil && !isCustom }

    private var settings: ChordSettings { records.first?.settings ?? ChordSettings() }
    private var presentation: SongPresentation { SongPresentation(song: song, settings: settings) }
    private var annotationsByLine: [LineAnchor: [AnnotationRecord]] {
        Dictionary(grouping: annotationRecords, by: \.anchor)
    }

    var body: some View {
        let blocks = presentation.blocks
        let byLine = annotationsByLine
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                header
                ForEach(Array(blocks.enumerated()), id: \.offset) { index, block in
                    BlockView(block: block, blockIndex: index, fontSize: fontSize, showChords: showChords,
                              annotations: byLine, isAnnotating: mode == .annotate, isEditing: mode == .edit,
                              onTapLine: { anchor in
                                  if mode == .edit { lineToEdit = anchor } else { editingLine = anchor }
                              },
                              onDelete: delete)
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
            .padding(.trailing, 18)
            .padding(.top, 12)
            .padding(.bottom, (mode == .draw ? 150 : 90) + (metronome.isPlaying ? 50 : 0)
                     + (queue != nil && mode == .read ? 50 : 0))
            .frame(maxWidth: 820, alignment: .leading)
            .frame(maxWidth: .infinity)
        }
        .scrollDisabled(mode == .draw && fingerDraws)
        .simultaneousGesture(zoomGesture, including: mode == .draw ? .subviews : .all)
        .background(NotebookPaper())
        .overlay(alignment: .bottom) {
            VStack(spacing: 10) {
                if mode == .draw {
                    DrawingPalette(tool: $tool, fingerDraws: $fingerDraws, onClearAll: clearDrawings)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                if metronome.isPlaying && !showTempo {
                    MetronomePill(metronome: metronome, onTap: { showTempo = true })
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                if let queue, mode == .read {
                    QueueBar(queue: queue, onOpen: onOpen)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
                ModeBar(mode: $mode)
            }
            .padding(.bottom, 10)
            .animation(.snappy, value: mode)
            .animation(.snappy, value: metronome.isPlaying)
        }
        .overlay {
            if let zoomHUD {
                Text("\(zoomHUD)%")
                    .font(.title3.weight(.bold).monospacedDigit())
                    .padding(.horizontal, 18)
                    .padding(.vertical, 10)
                    .background(.ultraThinMaterial, in: Capsule())
                    .transition(.opacity)
            }
        }
        .navigationTitle(song.displayTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
        .sheet(item: $editingLine) { anchor in
            AnnotationSheet(
                lineText: lineText(anchor, in: blocks),
                existing: (byLine[anchor] ?? []).sorted { $0.createdAt < $1.createdAt },
                onDelete: delete,
                onDeleteAll: {
                    for r in byLine[anchor] ?? [] { context.delete(r) }
                    try? context.save()
                },
                onVoice: { setVoice($0, at: anchor) },
                onInstrument: { add(.instrument, $0.id, detail: $1.rawValue, at: anchor) },
                onSticker: { add(.sticker, $0.id, at: anchor) },
                onNote: { add(.note, $0, at: anchor) },
                onMelody: { add(.melody, $0, at: anchor) }
            )
        }
        .sheet(item: $lineToEdit) { anchor in
            if let line = song.line(at: anchor) {
                LineEditSheet(line: line, suggestions: chordSuggestions, display: presentation.chord,
                              toOriginal: toOriginal) { edited in
                    save(song.replacingLine(at: anchor, with: edited))
                }
            }
        }
        .sheet(isPresented: $showTempo) {
            TempoSheet(bpm: bpmBinding, signature: signatureBinding, arrangement: arrangementBinding,
                       metronome: metronome)
        }
        .sheet(isPresented: $showEditor) {
            SongEditorSheet(heading: "Editar canción", title: song.displayTitle, blocks: song.blocks) { title, blocks in
                var edited = song
                edited.title = title
                edited.blocks = blocks
                save(edited)
            }
        }
        .confirmationDialog("¿Eliminar «\(song.displayTitle)»?", isPresented: $confirmDelete, titleVisibility: .visible) {
            Button("Eliminar canción", role: .destructive, action: deleteCustomSong)
        } message: {
            Text("Se borran también sus anotaciones y dibujos. No se puede deshacer.")
        }
        .onAppear(perform: syncMetronome)
        .onDisappear { metronome.stop() }
    }

    // MARK: Favoritas

    private var isFavorite: Bool { !favoriteRecords.isEmpty }

    private func toggleFavorite() {
        if favoriteRecords.isEmpty {
            context.insert(FavoriteRecord(songID: song.id))
        } else {
            for r in favoriteRecords { context.delete(r) }
        }
        try? context.save()
    }

    // MARK: Edición

    /// Acordes de la canción en el tono que se ve, sin repetir.
    private var chordSuggestions: [String] {
        var seen = Set<String>()
        return song.allChords.map(presentation.chord).filter { seen.insert($0).inserted }
    }

    /// Lo que el usuario escribe en el tono que ve se guarda en el tono original.
    private func toOriginal(_ chord: String) -> String {
        let p = presentation
        guard p.shapeOffset != 0 else { return chord }
        return Transposer.transpose(chord, by: -p.shapeOffset,
                                    accidentals: p.originalShapesKey?.preferredAccidentals ?? .sharps)
    }

    private func save(_ edited: Song) {
        if let editRecord {
            editRecord.song = edited
        } else {
            context.insert(SongEditRecord(song: edited, isCustom: false))
        }
        try? context.save()
    }

    private func restoreOriginal() {
        if let editRecord { context.delete(editRecord) }
        try? context.save()
    }

    /// Copia la canción (con sus ajustes, anotaciones y dibujos) a «Mis canciones».
    private func duplicate() {
        let customs = ((try? context.fetch(FetchDescriptor<SongEditRecord>())) ?? []).filter(\.isCustom)
        let number = max(SongEditRecord.firstCustomNumber - 1, customs.compactMap { $0.song?.number }.max() ?? 0) + 1
        let id = "mi-" + UUID().uuidString.prefix(8).lowercased()
        var copy = song.duplicated(id: id, number: number)
        copy.title = song.displayTitle + " (mi versión)"
        context.insert(SongEditRecord(song: copy, isCustom: true))
        for r in annotationRecords {
            if let kind = r.kind {
                context.insert(AnnotationRecord(songID: id, anchor: r.anchor, kind: kind, value: r.value, detail: r.detail))
            }
        }
        for d in drawingRecords {
            context.insert(DrawingRecord(songID: id, block: d.block, data: d.data))
        }
        if let s = records.first {
            let r = SongSettingsRecord(songID: id)
            r.settings = s.settings
            r.bpm = s.bpm
            r.timeSignature = s.timeSignature
            r.arrangement = s.arrangement
            context.insert(r)
        }
        try? context.save()
        onOpen(id)
    }

    private func deleteCustomSong() {
        metronome.stop()
        for r in annotationRecords { context.delete(r) }
        for d in drawingRecords { context.delete(d) }
        for s in records { context.delete(s) }
        for f in favoriteRecords { context.delete(f) }
        for list in setLists where list.songIDs.contains(song.id) {
            list.songIDs.removeAll { $0 == song.id }
        }
        if let editRecord { context.delete(editRecord) }
        try? context.save()
        onClose()
    }

    // MARK: Tempo

    private func settingsRecord() -> SongSettingsRecord {
        if let existing = records.first { return existing }
        let record = SongSettingsRecord(songID: song.id)
        context.insert(record)
        return record
    }

    private var bpmBinding: Binding<Int?> {
        Binding(get: { records.first?.bpm }, set: { value in
            settingsRecord().bpm = value
            try? context.save()
        })
    }

    private var signatureBinding: Binding<TimeSignature> {
        Binding(get: { records.first?.timeSignature ?? TimeSignature(beats: 4, unit: 4) }, set: { value in
            settingsRecord().timeSignature = value
            try? context.save()
        })
    }

    private var arrangementBinding: Binding<String> {
        Binding(get: { records.first?.arrangement ?? "" }, set: { value in
            settingsRecord().arrangement = value
            try? context.save()
        })
    }

    private func syncMetronome() {
        guard let record = records.first, let bpm = record.bpm else { return }
        metronome.configure(bpm: bpm, signature: record.timeSignature)
    }

    // MARK: Zoom

    /// Pellizcar con dos dedos agranda o achica la letra y los acordes (60 % a 240 %).
    private var zoomGesture: some Gesture {
        MagnifyGesture()
            .onChanged { value in
                let base = pinchBase ?? fontSize
                pinchBase = base
                fontSize = min(max(base * Double(value.magnification), 11), 44)
                zoomHUD = Int((fontSize / Self.baseFontSize * 100).rounded())
            }
            .onEnded { _ in
                pinchBase = nil
                withAnimation(.easeOut.delay(0.6)) { zoomHUD = nil }
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
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 14) {
                Text("\(song.number)")
                    .font(.system(size: 20, weight: .bold, design: .rounded).monospacedDigit())
                    .foregroundStyle(Theme.accent)
                    .frame(width: 46, height: 46)
                    .background(Theme.accent.opacity(0.10), in: RoundedRectangle(cornerRadius: 12))
                VStack(alignment: .leading, spacing: 3) {
                    Text(song.album.uppercased())
                        .font(.caption2.weight(.bold))
                        .tracking(1.2)
                        .foregroundStyle(Theme.secondaryInk)
                    Text(song.displayTitle)
                        .font(.system(.title2, design: .serif).weight(.bold))
                        .foregroundStyle(Theme.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            FlowLayout {
                Group {
                    if let key = presentation.soundingKey {
                        Chip(text: "Tono \(key.name(presentation.accidentals))", systemImage: "music.note")
                    }
                    Chip(text: presentation.capo == 0 ? "Sin cejilla" : "Cejilla \(presentation.capo)",
                         systemImage: "guitars")
                    Button { showTempo = true } label: {
                        if let record = records.first, let bpm = record.bpm {
                            Chip(text: "♩ = \(bpm) · \(record.timeSignature)", systemImage: "metronome", tint: Theme.chord)
                        } else {
                            Chip(text: "Añadir tempo", systemImage: "metronome", tint: Theme.secondaryInk)
                        }
                    }
                    .buttonStyle(.plain)
                    if isCustom {
                        Chip(text: "Mi canción", systemImage: "person.crop.circle", tint: .purple)
                    } else if isEditedOriginal {
                        Chip(text: "Editada", systemImage: "pencil", tint: .purple)
                    }
                    if settings.transpose != 0 {
                        Chip(text: settings.transpose > 0 ? "+\(settings.transpose) semitonos" : "\(settings.transpose) semitonos",
                             systemImage: "arrow.up.arrow.down", tint: .orange)
                    }
                }
                .padding(.trailing, 6)
                .padding(.bottom, 6)
            }
            let voices = Set(annotationRecords.filter { $0.kind == .voice }.compactMap { Voice(rawValue: $0.value) })
            if !voices.isEmpty {
                HStack(spacing: 14) {
                    ForEach(Voice.allCases.filter { voices.contains($0) }, id: \.self) { voice in
                        HStack(spacing: 5) {
                            Capsule().fill(Theme.voice(voice)).frame(width: 12, height: 4)
                            Text(voice.title)
                        }
                        .font(.caption.weight(.medium))
                        .foregroundStyle(Theme.voice(voice))
                    }
                }
            }
            if let arrangement = records.first?.arrangement, !arrangement.isEmpty {
                Button { showTempo = true } label: {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "music.note.list")
                            .foregroundStyle(Theme.accent)
                        VStack(alignment: .leading, spacing: 2) {
                            Text("ARREGLO")
                                .font(.caption2.weight(.bold))
                                .tracking(1)
                                .foregroundStyle(Theme.secondaryInk)
                            Text(arrangement)
                                .font(.subheadline)
                                .foregroundStyle(Theme.ink)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(10)
                    .background(Theme.paper, in: RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
            if !song.chordDefinitions.isEmpty {
                Text(song.chordDefinitions.sorted { $0.key < $1.key }
                    .map { "\(presentation.chord($0.key))  \($0.value)" }.joined(separator: "     "))
                    .font(.caption.monospaced())
                    .foregroundStyle(Theme.secondaryInk)
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.card, in: RoundedRectangle(cornerRadius: 18))
        .overlay(RoundedRectangle(cornerRadius: 18).strokeBorder(Theme.hairline))
        .shadow(color: .black.opacity(0.04), radius: 8, y: 3)
        .padding(.leading, -12)
    }

    // MARK: Barra de herramientas

    @ToolbarContentBuilder
    private var toolbar: some ToolbarContent {
        ToolbarItem(placement: .secondaryAction) {
            Button(action: toggleFavorite) {
                Label(isFavorite ? "Quitar de favoritas" : "Añadir a favoritas",
                      systemImage: isFavorite ? "star.fill" : "star")
            }
        }
        ToolbarItemGroup(placement: .primaryAction) {
            Button { change { $0.transpose -= 1 } } label: {
                Label("Bajar medio tono", systemImage: "minus.circle")
            }
            Menu {
                keyMenu
            } label: {
                Text(presentation.soundingKey?.name(presentation.accidentals) ?? "Tono")
                    .font(.system(.headline, design: .rounded))
                    .foregroundStyle(Theme.chord)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Theme.chord.opacity(0.12), in: Capsule())
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
        Section("Canción") {
            Button { showTempo = true } label: {
                Label("Tempo, metrónomo y arreglo", systemImage: "metronome")
            }
            Button { showEditor = true } label: {
                Label("Editar letra y acordes", systemImage: "square.and.pencil")
            }
            Button(action: toggleFavorite) {
                Label(isFavorite ? "Quitar de favoritas" : "Añadir a favoritas",
                      systemImage: isFavorite ? "star.slash" : "star")
            }
            Menu {
                ForEach(setLists) { list in
                    Button {
                        list.songIDs.append(song.id)
                        try? context.save()
                    } label: {
                        if list.songIDs.contains(song.id) {
                            Label(list.name, systemImage: "checkmark")
                        } else {
                            Text(list.name)
                        }
                    }
                }
                Button {
                    context.insert(SetListRecord(name: "Lista \(setLists.count + 1)", songIDs: [song.id]))
                    try? context.save()
                } label: {
                    Label("Lista nueva", systemImage: "plus")
                }
            } label: {
                Label("Añadir a una lista", systemImage: "text.badge.plus")
            }
            Button(action: duplicate) {
                Label("Duplicar como mi versión", systemImage: "plus.square.on.square")
            }
            if isEditedOriginal {
                Button(role: .destructive, action: restoreOriginal) {
                    Label("Restaurar canción original", systemImage: "arrow.uturn.backward")
                }
            }
            if isCustom {
                Button(role: .destructive) { confirmDelete = true } label: {
                    Label("Eliminar canción", systemImage: "trash")
                }
            }
        }
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
        Section("Zoom (también con dos dedos)") {
            Button { fontSize = min(fontSize + 2, 44) } label: {
                Label("Acercar", systemImage: "plus.magnifyingglass")
            }
            Button { fontSize = max(fontSize - 2, 11) } label: {
                Label("Alejar", systemImage: "minus.magnifyingglass")
            }
            Button { fontSize = Self.baseFontSize } label: {
                Label("Tamaño normal", systemImage: "1.magnifyingglass")
            }
            Toggle("Mostrar acordes", isOn: $showChords)
        }
        if !settings.isDefault {
            Button("Volver al tono original", role: .destructive) {
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

/// Barra flotante para cambiar entre Leer, Anotar, Dibujar y Editar.
private struct ModeBar: View {
    @Binding var mode: NotebookMode

    var body: some View {
        HStack(spacing: 4) {
            ForEach(NotebookMode.allCases) { m in
                Button {
                    mode = m
                } label: {
                    // Solo el modo activo muestra su nombre, para que quepan los cuatro.
                    HStack(spacing: 6) {
                        Image(systemName: m.symbol)
                        if mode == m { Text(m.title) }
                    }
                        .font(.subheadline.weight(.semibold))
                        .padding(.horizontal, mode == m ? 16 : 13)
                        .padding(.vertical, 10)
                        .background(mode == m ? Theme.accent : .clear, in: Capsule())
                        .foregroundStyle(mode == m ? Color.white : Theme.ink)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(m.title)
                .accessibilityAddTraits(mode == m ? .isSelected : [])
            }
        }
        .animation(.snappy, value: mode)
        .padding(5)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Theme.hairline))
        .shadow(color: .black.opacity(0.12), radius: 12, y: 4)
    }
}

/// Aviso flotante mientras suena el metrónomo: pulso, tempo y botón para parar.
private struct MetronomePill: View {
    @ObservedObject var metronome: Metronome
    let onTap: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            BeatDots(beats: metronome.signature.beats, current: metronome.beat,
                     signature: metronome.signature, size: 8)
            Button(action: onTap) {
                Text("\(metronome.bpm) BPM · \(metronome.signature.description)")
                    .font(.footnote.weight(.semibold).monospacedDigit())
                    .foregroundStyle(Theme.ink)
            }
            .buttonStyle(.plain)
            Button { metronome.stop() } label: {
                Image(systemName: "stop.fill")
                    .font(.footnote)
                    .frame(width: 28, height: 28)
                    .background(Color.red, in: Circle())
                    .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Parar metrónomo")
        }
        .padding(.leading, 14)
        .padding(.trailing, 6)
        .padding(.vertical, 6)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Theme.hairline))
        .shadow(color: .black.opacity(0.10), radius: 10, y: 3)
    }
}

extension Song {
    /// Los títulos del cancionero vienen en mayúsculas; los del usuario se dejan como están.
    var displayTitle: String {
        title == title.uppercased() ? title.capitalized(with: Locale(identifier: "es")) : title
    }
}

/// Anterior y siguiente dentro de la lista desde la que se abrió la canción.
private struct QueueBar: View {
    let queue: SongQueue
    let onOpen: (String) -> Void

    var body: some View {
        HStack(spacing: 0) {
            step(queue.previous, systemImage: "chevron.left", label: "Anterior")
            VStack(spacing: 0) {
                Text(queue.name)
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(Theme.secondaryInk)
                    .lineLimit(1)
                Text("\(queue.index + 1) de \(queue.count)")
                    .font(.footnote.weight(.semibold).monospacedDigit())
                    .foregroundStyle(Theme.ink)
            }
            .frame(minWidth: 90)
            step(queue.next, systemImage: "chevron.right", label: "Siguiente")
        }
        .padding(4)
        .background(.regularMaterial, in: Capsule())
        .overlay(Capsule().strokeBorder(Theme.hairline))
        .shadow(color: .black.opacity(0.10), radius: 10, y: 3)
    }

    private func step(_ song: Song?, systemImage: String, label: String) -> some View {
        Button {
            if let song { onOpen(song.id) }
        } label: {
            Image(systemName: systemImage)
                .font(.subheadline.weight(.bold))
                .frame(width: 40, height: 36)
                .foregroundStyle(song == nil ? Theme.hairline : Theme.accent)
        }
        .buttonStyle(.plain)
        .disabled(song == nil)
        .accessibilityLabel(song.map { "\(label): \($0.displayTitle)" } ?? label)
    }
}
