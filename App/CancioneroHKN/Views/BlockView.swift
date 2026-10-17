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
            HStack(alignment: .center, spacing: 10) {
                SectionTag(text: label ?? "Instrumental", fontSize: fontSize)
                if showChords {
                    Text(label == nil ? text : chords.joined(separator: "   "))
                        .font(Theme.chordFont(fontSize))
                        .foregroundStyle(Theme.chord)
                }
            }
            .padding(.vertical, 2)
        case let .directive(text):
            Text(text)
                .font(Theme.lyricFont(fontSize * 0.85).italic())
                .foregroundStyle(Theme.secondaryInk)
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
                Capsule()
                    .fill(marks.voice.map { Theme.voice($0.voice) } ?? .clear)
                    .frame(width: 4)
                    .contextMenu { if let v = marks.voice { deleteButton(v.record) } }
                content
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, marks.voice == nil ? 0 : 3)
                    .padding(.horizontal, marks.voice == nil ? 0 : 6)
                    .background(marks.voice.map { Theme.voice($0.voice).opacity(0.09) } ?? .clear,
                                in: RoundedRectangle(cornerRadius: 8))
                if !marks.instruments.isEmpty || !marks.stickers.isEmpty {
                    trailingMarks
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            ForEach(marks.notes, id: \.id) { note in
                Label(note.value, systemImage: "note.text")
                    .font(.system(size: fontSize * 0.75, weight: .medium, design: .rounded))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Theme.note, in: RoundedRectangle(cornerRadius: 6))
                    .foregroundStyle(Theme.noteInk)
                    .shadow(color: .black.opacity(0.08), radius: 2, y: 1)
                    .padding(.leading, 12)
                    .contextMenu { deleteButton(note) }
            }
        }
        .overlay(alignment: .leading) {
            if isAnnotating {
                Image(systemName: marks.isEmpty ? "plus.circle" : "ellipsis.circle.fill")
                    .font(.system(size: 13))
                    .foregroundStyle(Theme.accent.opacity(marks.isEmpty ? 0.45 : 0.9))
                    .offset(x: -20)
            }
        }
    }

    private var trailingMarks: some View {
        VStack(alignment: .trailing, spacing: 2) {
            ForEach(marks.instruments, id: \.record.id) { item in
                HStack(spacing: 3) {
                    Text(item.instrument.emoji)
                    Image(systemName: item.cue == .enters ? "arrow.right" : "stop.fill")
                        .font(.system(size: fontSize * 0.5, weight: .bold))
                        .foregroundStyle(item.cue == .enters ? Color.green : Color.red)
                }
                .font(.system(size: fontSize * 0.75))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Theme.card, in: Capsule())
                .overlay(Capsule().strokeBorder(Theme.hairline))
                .accessibilityLabel("\(item.instrument.name): \(item.cue.title)")
                .contextMenu {
                    Text("\(item.instrument.name) · \(item.cue.title)")
                    deleteButton(item.record)
                }
            }
            ForEach(marks.stickers, id: \.record.id) { item in
                StickerGlyph(sticker: item.sticker, size: fontSize * 0.75)
                    .foregroundStyle(Theme.accent)
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
                                    .font(Theme.chordFont(fontSize))
                                    .foregroundStyle(Theme.chord)
                            }
                            Text(piece.text.isEmpty ? " " : piece.text)
                                .font(Theme.lyricFont(fontSize))
                                .foregroundStyle(Theme.ink)
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

