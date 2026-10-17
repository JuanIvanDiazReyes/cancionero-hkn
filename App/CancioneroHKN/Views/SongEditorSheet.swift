import CancioneroCore
import SwiftUI

/// Editor de la canción completa como texto, con los acordes entre corchetes.
/// Sirve para corregir una canción y para escribir una nueva.
struct SongEditorSheet: View {
    let heading: String
    let onSave: (_ title: String, _ blocks: [SongBlock]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var title: String
    @State private var text: String
    @State private var showPreview = false
    @State private var showHelp: Bool
    private let initialText: String
    private let initialTitle: String

    init(heading: String, title: String, blocks: [SongBlock],
         onSave: @escaping (_ title: String, _ blocks: [SongBlock]) -> Void) {
        self.heading = heading
        self.onSave = onSave
        let text = SongText.text(for: blocks)
        _title = State(initialValue: title)
        _text = State(initialValue: text)
        _showHelp = State(initialValue: blocks.isEmpty)
        initialText = text
        initialTitle = title
    }

    private var blocks: [SongBlock] { SongText.blocks(from: text) }
    private var trimmedTitle: String { title.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var hasChanges: Bool { text != initialText || title != initialTitle }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(spacing: 12) {
                    TextField("Título de la canción", text: $title)
                        .font(.system(.title3, design: .serif).weight(.bold))
                        .padding(12)
                        .background(Theme.card, in: RoundedRectangle(cornerRadius: 12))
                        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Theme.hairline))
                    Picker("Vista", selection: $showPreview) {
                        Text("Texto").tag(false)
                        Text("Vista previa").tag(true)
                    }
                    .pickerStyle(.segmented)
                    if showHelp && !showPreview { help }
                }
                .padding([.horizontal, .top])
                .padding(.bottom, 10)

                if showPreview {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 20) {
                            ForEach(Array(blocks.enumerated()), id: \.offset) { index, block in
                                BlockView(block: block, blockIndex: index, fontSize: 17, showChords: true,
                                          annotations: [:], isAnnotating: false,
                                          onTapLine: { _ in }, onDelete: { _ in })
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.vertical)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .background(Theme.paper)
                } else {
                    TextEditor(text: $text)
                        .font(.system(size: 16, design: .monospaced))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.sentences)
                        .scrollContentBackground(.hidden)
                        .padding(.horizontal, 12)
                        .background(Theme.card)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle(heading)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Guardar") {
                        onSave(trimmedTitle, blocks)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(trimmedTitle.isEmpty || blocks.isEmpty || !hasChanges)
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { withAnimation { showHelp.toggle() } } label: {
                        Label("Ayuda", systemImage: showHelp ? "questionmark.circle.fill" : "questionmark.circle")
                    }
                }
            }
            .interactiveDismissDisabled(hasChanges)
        }
    }

    private var help: some View {
        VStack(alignment: .leading, spacing: 6) {
            helpRow("[G]Hola [D/F#]mundo", "acorde sobre la sílaba que sigue")
            helpRow("| INTRO: G D Em C", "línea solo de acordes")
            helpRow("> (CORO X2)", "indicación")
            helpRow("línea en blanco", "separa estrofas")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(Theme.chord.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
        .transition(.opacity.combined(with: .move(edge: .top)))
    }

    private func helpRow(_ example: String, _ meaning: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(example)
                .font(.system(.footnote, design: .monospaced).weight(.semibold))
                .foregroundStyle(Theme.chord)
            Text(meaning)
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }
}
