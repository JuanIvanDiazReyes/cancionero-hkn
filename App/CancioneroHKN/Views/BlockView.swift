import CancioneroCore
import SwiftUI

/// Un bloque de la canción (estrofa, coro, INTRO…).
struct BlockView: View {
    let block: SongBlock
    let fontSize: Double
    let showChords: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            ForEach(Array(block.lines.enumerated()), id: \.offset) { _, line in
                lineView(line)
            }
        }
    }

    @ViewBuilder
    private func lineView(_ line: SongLine) -> some View {
        switch line {
        case let .lyric(text, chords):
            ChordLyricLine(text: text, chords: showChords ? chords : [], fontSize: fontSize)
        case let .instrumental(label, chords, text):
            if showChords || label != nil {
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
                    }
                }
            }
        case let .directive(text):
            Text(text)
                .font(.system(size: fontSize * 0.85).italic())
                .foregroundStyle(.secondary)
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
