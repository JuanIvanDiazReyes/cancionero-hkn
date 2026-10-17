import CancioneroCore
import SwiftUI

/// Anotaciones de una línea, ya agrupadas por tipo.
struct LineMarks {
    struct VoiceMark { let record: AnnotationRecord; let voice: Voice }
    struct InstrumentMark { let record: AnnotationRecord; let instrument: Instrument; let cue: InstrumentCue }
    struct StickerMark { let record: AnnotationRecord; let sticker: Sticker }

    var voice: VoiceMark?
    var instruments: [InstrumentMark] = []
    var stickers: [StickerMark] = []
    var notes: [AnnotationRecord] = []

    init(_ records: [AnnotationRecord]) {
        for r in records.sorted(by: { $0.createdAt < $1.createdAt }) {
            switch r.kind {
            case .voice:
                if let v = Voice(rawValue: r.value) { voice = VoiceMark(record: r, voice: v) }
            case .instrument:
                if let i = Instrument.find(r.value) {
                    instruments.append(InstrumentMark(record: r, instrument: i,
                                                      cue: r.detail.flatMap(InstrumentCue.init(rawValue:)) ?? .enters))
                }
            case .sticker:
                if let st = Sticker.find(r.value) { stickers.append(StickerMark(record: r, sticker: st)) }
            case .note:
                notes.append(r)
            case nil:
                break
            }
        }
    }

    var isEmpty: Bool { voice == nil && instruments.isEmpty && stickers.isEmpty && notes.isEmpty }
}

/// Un bloque de la canción (estrofa, coro, INTRO…) con sus anotaciones.
struct BlockView: View {
    let block: SongBlock
    let blockIndex: Int
    let fontSize: Double
    let showChords: Bool
    let annotations: [LineAnchor: [AnnotationRecord]]
    let isAnnotating: Bool
    let onTapLine: (LineAnchor) -> Void
    let onDelete: (AnnotationRecord) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(block.lines.enumerated()), id: \.offset) { index, line in
                let anchor = LineAnchor(block: blockIndex, line: index)
                LineRow(marks: LineMarks(annotations[anchor] ?? []), fontSize: fontSize,
                        isAnnotating: isAnnotating, onDelete: onDelete) {
                    lineView(line)
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if isAnnotating { onTapLine(anchor) }
                }
            }
        }
    }

    @ViewBuilder
    private func lineView(_ line: SongLine) -> some View {
        switch line {
        case let .lyric(text, chords):
            ChordLyricLine(text: text, chords: showChords ? chords : [], fontSize: fontSize)
        case let .instrumental(label, chords, text):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if let label {
                    Text(label)
                        .font(.system(size: fontSize * 0.7, weight: .heavy))
                        .foregroundStyle(.secondary)
                }
                if showChords {
                    Text(label == nil ? text : chords.joined(separator: "  "))
                        .font(.system(size: fontSize * 0.9, weight: .bold))
                        .foregroundStyle(Color.chord)
                } else if label == nil {
                    Text("(instrumental)")
                        .font(.system(size: fontSize * 0.8).italic())
                        .foregroundStyle(.secondary)
                }
            }
        case let .directive(text):
            Text(text)
                .font(.system(size: fontSize * 0.85).italic())
                .foregroundStyle(.secondary)
        }
    }
}

/// Una línea con la franja de voz a la izquierda, instrumentos e iconos a la derecha
/// y las notas debajo.
private struct LineRow<Content: View>: View {
    let marks: LineMarks
    let fontSize: Double
    let isAnnotating: Bool
    let onDelete: (AnnotationRecord) -> Void
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 8) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(marks.voice.map { Notebook.color($0.voice) } ?? .clear)
                    .frame(width: 5)
                    .contextMenu { if let v = marks.voice { deleteButton(v.record) } }
                content
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, marks.voice == nil ? 0 : 2)
                    .padding(.horizontal, marks.voice == nil ? 0 : 4)
                    .background(marks.voice.map { Notebook.color($0.voice).opacity(0.10) } ?? .clear,
                                in: RoundedRectangle(cornerRadius: 6))
                if !marks.instruments.isEmpty || !marks.stickers.isEmpty {
                    trailingMarks
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            ForEach(marks.notes, id: \.id) { note in
                Text(note.value)
                    .font(.system(size: fontSize * 0.8))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Notebook.note, in: RoundedRectangle(cornerRadius: 4))
                    .foregroundStyle(.black)
                    .rotationEffect(.degrees(-1))
                    .padding(.leading, 13)
                    .contextMenu { deleteButton(note) }
            }
        }
        .overlay(alignment: .leading) {
            if isAnnotating && marks.isEmpty {
                Image(systemName: "plus.circle")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .offset(x: -16)
            }
        }
    }

    private var trailingMarks: some View {
        VStack(alignment: .trailing, spacing: 2) {
            ForEach(marks.instruments, id: \.record.id) { item in
                HStack(spacing: 2) {
                    Text(item.instrument.emoji)
                    Image(systemName: item.cue == .enters ? "arrow.right.circle.fill" : "xmark.circle.fill")
                        .foregroundStyle(item.cue == .enters ? Color.green : Color.red)
                }
                .font(.system(size: fontSize * 0.8))
                .accessibilityLabel("\(item.instrument.name): \(item.cue.title)")
                .contextMenu {
                    Text("\(item.instrument.name) · \(item.cue.title)")
                    deleteButton(item.record)
                }
            }
            ForEach(marks.stickers, id: \.record.id) { item in
                StickerGlyph(sticker: item.sticker, size: fontSize * 0.8)
                    .foregroundStyle(Color.chord)
                    .accessibilityLabel(item.sticker.name)
                    .contextMenu {
                        Text(item.sticker.name)
                        deleteButton(item.record)
                    }
            }
        }
    }

    private func deleteButton(_ record: AnnotationRecord) -> some View {
        Button(role: .destructive) { onDelete(record) } label: {
            Label("Quitar", systemImage: "trash")
        }
    }
}

/// Una línea de letra con cada acorde encima de su sílaba.
/// Las palabras saltan de línea como un texto normal cuando no caben.
struct ChordLyricLine: View {
    let text: String
    let chords: [PositionedChord]
    let fontSize: Double

    var body: some View {
        let words = ChordLayout.words(text: text, chords: chords)
        let hasChords = !chords.isEmpty
        FlowLayout(lineSpacing: hasChords ? 2 : 0) {
            ForEach(Array(words.enumerated()), id: \.offset) { _, word in
                HStack(alignment: .bottom, spacing: 0) {
                    ForEach(Array(word.pieces.enumerated()), id: \.offset) { _, piece in
                        VStack(alignment: .leading, spacing: 0) {
                            if hasChords {
                                Text(piece.chord.map { $0 + " " } ?? " ")
                                    .font(.system(size: fontSize * 0.85, weight: .bold))
                                    .foregroundStyle(Color.chord)
                            }
                            Text(piece.text.isEmpty ? " " : piece.text)
                                .font(.system(size: fontSize))
                        }
                        .fixedSize()
                    }
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(text)
    }
}

/// Coloca las vistas una tras otra y salta de línea cuando no caben.
struct FlowLayout: Layout {
    var lineSpacing: CGFloat = 0

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(width: proposal.width ?? .infinity, subviews: subviews)
        let width = rows.map(\.width).max() ?? 0
        let height = rows.map(\.height).reduce(0, +) + lineSpacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: proposal.width ?? width, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(width: bounds.width, subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y + row.height - size.height),
                                      proposal: .unspecified)
                x += size.width
            }
            y += row.height + lineSpacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(width: CGFloat, subviews: Subviews) -> [Row] {
        var rows: [Row] = []
        var row = Row()
        for (index, subview) in subviews.enumerated() {
            let size = subview.sizeThatFits(.unspecified)
            if !row.indices.isEmpty && row.width + size.width > width {
                rows.append(row)
                row = Row()
            }
            row.indices.append(index)
            row.width += size.width
            row.height = max(row.height, size.height)
        }
        if !row.indices.isEmpty { rows.append(row) }
        return rows
    }
}

extension Color {
    /// Color de los acordes.
    static let chord = Color(red: 0.80, green: 0.25, blue: 0.10)
}
