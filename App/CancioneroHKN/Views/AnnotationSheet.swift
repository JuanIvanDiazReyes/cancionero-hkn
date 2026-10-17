import CancioneroCore
import SwiftUI

/// Hoja para anotar una línea: voz, instrumento, icono musical o nota.
struct AnnotationSheet: View {
    let lineText: String
    let currentVoice: Voice?
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
                        .font(.callout.italic())
                        .foregroundStyle(.secondary)
                        .lineLimit(2)

                    section("¿Quién canta?") {
                        HStack(spacing: 10) {
                            ForEach(Voice.allCases, id: \.self) { voice in
                                Button {
                                    onVoice(currentVoice == voice ? nil : voice)
                                    dismiss()
                                } label: {
                                    Label(voice.title, systemImage: currentVoice == voice ? "checkmark.circle.fill" : "circle.fill")
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 10)
                                        .background(Notebook.color(voice).opacity(0.18), in: RoundedRectangle(cornerRadius: 10))
                                        .foregroundStyle(Notebook.color(voice))
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
                                        .foregroundStyle(Color.chord)
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

    private func section<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title).font(.headline)
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
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }
}
