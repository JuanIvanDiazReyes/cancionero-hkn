import CancioneroCore
import SwiftUI

/// Hoja para anotar una línea: voz, instrumento, icono musical o nota.
struct AnnotationSheet: View {
    let lineText: String
    let existing: [AnnotationRecord]
    let onDelete: (AnnotationRecord) -> Void
    let onDeleteAll: () -> Void
    let onVoice: (Voice?) -> Void
    let onInstrument: (Instrument, InstrumentCue) -> Void
    let onSticker: (Sticker) -> Void
    let onNote: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var cue: InstrumentCue = .enters
    @State private var noteText = ""

    private let columns = [GridItem(.adaptive(minimum: 76), spacing: 10)]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text(lineText)
                        .font(Theme.lyricFont(17).italic())
                        .foregroundStyle(Theme.secondaryInk)
                        .lineLimit(2)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(12)
                        .background(Theme.paper, in: RoundedRectangle(cornerRadius: 12))

                    if !existing.isEmpty {
                        section("En esta línea") {
                            VStack(spacing: 0) {
                                ForEach(existing, id: \.id) { record in
                                    HStack(spacing: 12) {
                                        ExistingMarkIcon(record: record)
                                            .frame(width: 28)
                                        Text(describe(record))
                                            .font(.subheadline)
                                            .lineLimit(2)
                                        Spacer()
                                        Button(role: .destructive) { onDelete(record) } label: {
                                            Image(systemName: "trash")
                                                .foregroundStyle(.red)
                                                .padding(8)
                                                .background(Color.red.opacity(0.1), in: Circle())
                                        }
                                        .buttonStyle(.plain)
                                        .accessibilityLabel("Eliminar \(describe(record))")
                                    }
                                    .padding(.vertical, 8)
                                    if record.id != existing.last?.id { Divider() }
                                }
                            }
                            .padding(.horizontal, 12)
                            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                            Button(role: .destructive, action: onDeleteAll) {
                                Label("Eliminar todo de esta línea", systemImage: "trash")
                                    .font(.footnote.weight(.semibold))
                            }
                        }
                    }

                    section("¿Quién canta?") {
                        HStack(spacing: 10) {
                            ForEach(Voice.allCases, id: \.self) { voice in
                                Button {
                                    onVoice(currentVoice == voice ? nil : voice)
                                    dismiss()
                                } label: {
                                    Label(voice.title, systemImage: currentVoice == voice ? "checkmark.circle.fill" : "circle.fill")
                                        .font(.subheadline.weight(.semibold))
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                        .background(Theme.voice(voice).opacity(currentVoice == voice ? 0.25 : 0.12),
                                                    in: RoundedRectangle(cornerRadius: 12))
                                        .overlay(RoundedRectangle(cornerRadius: 12)
                                            .strokeBorder(Theme.voice(voice), lineWidth: currentVoice == voice ? 2 : 0))
                                        .foregroundStyle(Theme.voice(voice))
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }

                    section("Instrumento") {
                        Picker("Entra o sale", selection: $cue) {
                            ForEach(InstrumentCue.allCases, id: \.self) { Text($0.title).tag($0) }
                        }
                        .pickerStyle(.segmented)
                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(Instrument.all) { instrument in
                                tile(title: instrument.short) {
                                    Text(instrument.emoji).font(.title2)
                                } action: {
                                    onInstrument(instrument, cue)
                                    dismiss()
                                }
                            }
                        }
                    }

                    section("Indicaciones") {
                        LazyVGrid(columns: columns, spacing: 10) {
                            ForEach(Sticker.all) { sticker in
                                tile(title: sticker.name) {
                                    StickerGlyph(sticker: sticker, size: 20)
                                        .foregroundStyle(Theme.accent)
                                } action: {
                                    onSticker(sticker)
                                    dismiss()
                                }
                            }
                        }
                    }

                    section("Nota") {
                        TextField("Escribe una nota (p. ej. \"entra el coro suave\")", text: $noteText, axis: .vertical)
                            .lineLimit(1...4)
                            .textFieldStyle(.roundedBorder)
                        Button("Añadir nota") {
                            let text = noteText.trimmingCharacters(in: .whitespacesAndNewlines)
                            guard !text.isEmpty else { return }
                            onNote(text)
                            dismiss()
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    }
                }
                .padding()
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Anotar línea")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cerrar") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private var currentVoice: Voice? {
        existing.first { $0.kind == .voice }.flatMap { Voice(rawValue: $0.value) }
    }

    private func describe(_ record: AnnotationRecord) -> String {
        switch record.kind {
        case .voice: return "Voz: " + (Voice(rawValue: record.value)?.title ?? record.value)
        case .instrument:
            let cue = record.detail.flatMap(InstrumentCue.init(rawValue:)) ?? .enters
            return (Instrument.find(record.value)?.name ?? record.value) + " · " + cue.title
        case .sticker: return Sticker.find(record.value)?.name ?? record.value
        case .note: return "Nota: " + record.value
        case nil: return record.value
        }
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

    private func tile<Icon: View>(title: String, @ViewBuilder icon: () -> Icon,
                                  action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(spacing: 4) {
                icon().frame(height: 28)
                Text(title)
                    .font(.caption2)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, minHeight: 64)
            .padding(4)
            .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

/// Icono pequeño de una anotación existente.
private struct ExistingMarkIcon: View {
    let record: AnnotationRecord

    var body: some View {
        switch record.kind {
        case .voice:
            Circle()
                .fill(Voice(rawValue: record.value).map(Theme.voice) ?? .gray)
                .frame(width: 14, height: 14)
        case .instrument:
            Text(Instrument.find(record.value)?.emoji ?? "🎵")
        case .sticker:
            if let sticker = Sticker.find(record.value) {
                StickerGlyph(sticker: sticker, size: 15).foregroundStyle(Theme.accent)
            }
        case .note, nil:
            Image(systemName: "note.text").foregroundStyle(Theme.noteInk)
        }
    }
}
