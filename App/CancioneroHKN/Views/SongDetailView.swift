import CancioneroCore
import SwiftData
import SwiftUI

/// Una canción con sus acordes, tono y cejilla ajustables.
struct SongDetailView: View {
    let song: Song

    @Environment(\.modelContext) private var context
    @Query private var records: [SongSettingsRecord]
    @AppStorage("fontSize") private var fontSize: Double = 18
    @AppStorage("showChords") private var showChords = true

    init(song: Song) {
        self.song = song
        let id = song.id
        _records = Query(filter: #Predicate<SongSettingsRecord> { $0.songID == id })
    }

    private var settings: ChordSettings { records.first?.settings ?? ChordSettings() }
    private var presentation: SongPresentation { SongPresentation(song: song, settings: settings) }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                header
                ForEach(Array(presentation.blocks.enumerated()), id: \.offset) { _, block in
                    BlockView(block: block, fontSize: fontSize, showChords: showChords)
                }
            }
            .padding(.horizontal, 20)
            .padding(.vertical, 16)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .navigationTitle(song.title.capitalized(with: Locale(identifier: "es")))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar { toolbar }
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
