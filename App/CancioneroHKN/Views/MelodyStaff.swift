import CancioneroCore
import SwiftUI

/// Un pentagrama corto en clave de sol con las notas de una melodía
/// y sus nombres debajo, para quien no lee partitura.
struct MelodyStaff: View {
    let items: [MelodyItem]
    /// Distancia entre líneas del pentagrama.
    var spacing: CGFloat = 7
    var showNames = true
    var solfege = true

    private var noteGap: CGFloat { spacing * 3.4 }
    private var clefWidth: CGFloat { spacing * 4 }
    /// Pasos libres por arriba y por abajo para líneas adicionales.
    private var topSteps: Int { max(10, (items.compactMap(\.step).max() ?? 0) + 2) }
    private var bottomSteps: Int { min(-3, (items.compactMap(\.step).min() ?? 0) - 2) }
    private var stepHeight: CGFloat { spacing / 2 }
    private var staffHeight: CGFloat { CGFloat(topSteps - bottomSteps) * stepHeight + spacing * 2 }
    private var width: CGFloat {
        clefWidth + items.reduce(CGFloat(0)) { $0 + ($1 == .bar ? spacing * 1.6 : noteGap) } + spacing
    }

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            VStack(alignment: .leading, spacing: 2) {
                Canvas { context, size in draw(in: &context, size: size) }
                    .frame(width: width, height: staffHeight)
                if showNames {
                    names
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityText)
    }

    private var names: some View {
        HStack(spacing: 0) {
            Color.clear.frame(width: clefWidth)
            ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                switch item {
                case .bar:
                    Color.clear.frame(width: spacing * 1.6)
                case let .note(note):
                    Text(note.isRest ? "–" : shortName(note))
                        .font(.system(size: max(spacing * 1.25, 9), weight: .semibold, design: .rounded))
                        .foregroundStyle(Theme.secondaryInk)
                        .frame(width: noteGap)
                }
            }
        }
    }

    private func shortName(_ note: MelodyNote) -> String {
        // Sin el número de octava, salvo fuera de la octava central.
        let full = Melody.name(of: note, solfege: solfege)
        let octave = full.last.flatMap { Int(String($0)) }
        return octave == 4 ? String(full.dropLast()) : full
    }

    private var accessibilityText: String {
        "Melodía: " + items.compactMap { item -> String? in
            if case let .note(n) = item { return n.isRest ? "silencio" : Melody.name(of: n, solfege: solfege) }
            return nil
        }.joined(separator: ", ")
    }

    // MARK: Dibujo

    private func y(forStep step: Int) -> CGFloat {
        spacing + CGFloat(topSteps - step) * stepHeight
    }

    private func draw(in context: inout GraphicsContext, size: CGSize) {
        let ink = GraphicsContext.Shading.color(Theme.ink)
        let line = GraphicsContext.Shading.color(Theme.secondaryInk.opacity(0.7))

        // Cinco líneas: pasos 0, 2, 4, 6, 8.
        for step in stride(from: 0, through: 8, by: 2) {
            var path = Path()
            path.move(to: CGPoint(x: 0, y: y(forStep: step)))
            path.addLine(to: CGPoint(x: size.width, y: y(forStep: step)))
            context.stroke(path, with: line, lineWidth: 0.8)
        }
        context.draw(Text("𝄞").font(.system(size: spacing * 6.2)).foregroundStyle(Theme.ink),
                     at: CGPoint(x: clefWidth * 0.45, y: y(forStep: 3)), anchor: .center)

        var x = clefWidth
        for item in items {
            switch item {
            case .bar:
                var path = Path()
                path.move(to: CGPoint(x: x + spacing * 0.8, y: y(forStep: 8)))
                path.addLine(to: CGPoint(x: x + spacing * 0.8, y: y(forStep: 0)))
                context.stroke(path, with: line, lineWidth: 1)
                x += spacing * 1.6
            case let .note(note):
                let center = x + noteGap / 2
                if let step = note.staffStep {
                    drawNote(note, step: step, centerX: center, in: &context, ink: ink, line: line)
                } else {
                    drawRest(note.value, centerX: center, in: &context, ink: ink)
                }
                x += noteGap
            }
        }
    }

    private func drawNote(_ note: MelodyNote, step: Int, centerX: CGFloat,
                          in context: inout GraphicsContext,
                          ink: GraphicsContext.Shading, line: GraphicsContext.Shading) {
        let cy = y(forStep: step)
        let headW = spacing * 1.35, headH = spacing * 0.95

        // Líneas adicionales arriba o abajo del pentagrama.
        let ledgers = step < 0 ? Array(stride(from: -2, through: step, by: -2))
            : step > 8 ? Array(stride(from: 10, through: step, by: 2)) : []
        for s in ledgers {
            var path = Path()
            path.move(to: CGPoint(x: centerX - headW, y: y(forStep: s)))
            path.addLine(to: CGPoint(x: centerX + headW, y: y(forStep: s)))
            context.stroke(path, with: line, lineWidth: 0.8)
        }

        // Cabeza ovalada, un poco inclinada; hueca en blancas y redondas.
        let head = Path(ellipseIn: CGRect(x: -headW / 2, y: -headH / 2, width: headW, height: headH))
            .applying(CGAffineTransform(rotationAngle: -0.35))
            .applying(CGAffineTransform(translationX: centerX, y: cy))
        if note.value == .whole || note.value == .half {
            context.stroke(head, with: ink, lineWidth: 1.4)
        } else {
            context.fill(head, with: ink)
        }

        if note.accidental != 0 {
            context.draw(Text(note.accidental > 0 ? "♯" : "♭")
                .font(.system(size: spacing * 1.7, weight: .medium)).foregroundStyle(Theme.ink),
                         at: CGPoint(x: centerX - headW * 1.25, y: cy), anchor: .center)
        }
        if note.dotted {
            let dot = Path(ellipseIn: CGRect(x: centerX + headW * 0.8, y: cy - spacing * 0.45,
                                             width: spacing * 0.35, height: spacing * 0.35))
            context.fill(dot, with: ink)
        }

        guard note.value != .whole else { return }
        // Plica hacia arriba en la mitad de abajo y hacia abajo en la de arriba.
        let up = step < 4
        let stemX = up ? centerX + headW / 2 - 0.6 : centerX - headW / 2 + 0.6
        let stemEnd = up ? cy - spacing * 3.3 : cy + spacing * 3.3
        var stem = Path()
        stem.move(to: CGPoint(x: stemX, y: cy))
        stem.addLine(to: CGPoint(x: stemX, y: stemEnd))
        context.stroke(stem, with: ink, lineWidth: 1.1)

        let flags = note.value == .eighth ? 1 : note.value == .sixteenth ? 2 : 0
        for f in 0..<flags {
            let start = stemEnd + CGFloat(f) * (up ? spacing * 0.8 : -spacing * 0.8)
            var flag = Path()
            flag.move(to: CGPoint(x: stemX, y: start))
            flag.addQuadCurve(to: CGPoint(x: stemX + spacing * 0.9, y: start + (up ? spacing * 1.8 : -spacing * 1.8)),
                              control: CGPoint(x: stemX + spacing * 1.1, y: start + (up ? spacing * 0.6 : -spacing * 0.6)))
            context.stroke(flag, with: ink, lineWidth: 1.3)
        }
    }

    private func drawRest(_ value: NoteValue, centerX: CGFloat, in context: inout GraphicsContext,
                          ink: GraphicsContext.Shading) {
        switch value {
        case .whole, .half:
            // Redonda: cuelga de la cuarta línea; blanca: apoyada en la tercera.
            let top = value == .whole ? y(forStep: 6) : y(forStep: 4) - spacing * 0.5
            context.fill(Path(CGRect(x: centerX - spacing * 0.7, y: top, width: spacing * 1.4, height: spacing * 0.5)),
                         with: ink)
        default:
            var path = Path()
            let top = y(forStep: 7)
            path.move(to: CGPoint(x: centerX - spacing * 0.3, y: top))
            path.addLine(to: CGPoint(x: centerX + spacing * 0.4, y: top + spacing * 0.9))
            path.addLine(to: CGPoint(x: centerX - spacing * 0.3, y: top + spacing * 1.8))
            path.addLine(to: CGPoint(x: centerX + spacing * 0.4, y: top + spacing * 2.7))
            path.addQuadCurve(to: CGPoint(x: centerX, y: top + spacing * 3.6),
                              control: CGPoint(x: centerX - spacing * 0.6, y: top + spacing * 2.9))
            context.stroke(path, with: ink, style: StrokeStyle(lineWidth: 1.6, lineCap: .round, lineJoin: .round))
            if value != .quarter {
                context.draw(Text(value == .eighth ? "8" : "16").font(.system(size: spacing)),
                             at: CGPoint(x: centerX + spacing, y: top), anchor: .center)
            }
        }
    }
}

private extension MelodyItem {
    var step: Int? {
        if case let .note(n) = self { return n.staffStep }
        return nil
    }
}
